const env = require('../config/env');
const { pool } = require('../config/database');

function normalizePhone(value) {
  if (!value) return null;
  const phone = String(value).replace(/[ ()-]/g, '');
  return /^\+?[1-9]\d{6,14}$/.test(phone) ? phone : null;
}

function buildMessage(user, accident, vehicle, eventId, locationAge) {
  const map = `https://www.google.com/maps?q=${accident.latitude},${accident.longitude}`;
  const vehicleText = vehicle ? `${vehicle.plate_number} ${vehicle.model} (${vehicle.color})` : 'Not registered';
  return `RESQDRIVE EMERGENCY ALERT\nPossible vehicle accident detected.\nDriver: ${user.full_name}\nPhone: ${user.phone || 'Unavailable'}\nVehicle: ${vehicleText}\nTime: ${new Date(accident.detected_at).toISOString()}\nStatus: Confirmed\nSeverity: ${accident.peak_g_force ?? 'Unavailable'}\nLocation${locationAge ? ' (last known)' : ''}: ${accident.latitude}, ${accident.longitude}\n${map}\nEmergency Reference ID: ${eventId}\nAutomated RESQDRIVE notification. Arrange assistance.`;
}

async function sendViaTextBee(phone, message) {
  if (!env.textbee.enabled) throw new Error('SMS provider is disabled; no message was sent');
  if (!env.textbee.apiKey) throw new Error('TextBee is enabled but TEXTBEE_API_KEY is not configured');
  let lastError;
  for (let attempt = 0; attempt <= env.textbee.maxRetries; attempt += 1) {
    try {
      const response = await fetch(`${env.textbee.baseUrl}/gateway/send-sms`, { method: 'POST', headers: { 'content-type': 'application/json', 'x-api-key': env.textbee.apiKey }, signal: AbortSignal.timeout(10000), body: JSON.stringify({ recipients: [phone], message, ...(env.textbee.deviceId ? { deviceId: env.textbee.deviceId } : {}) }) });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) throw new Error(body.message || body.error || `TextBee HTTP ${response.status}`);
      return { provider: 'TEXTBEE', providerMessageId: body.smsBatchId || body.data?.smsBatchId || null };
    } catch (error) { lastError = error; if (attempt < env.textbee.maxRetries) await new Promise(resolve => setTimeout(resolve, 250 * (2 ** attempt))); }
  }
  throw lastError;
}

async function notifyEvent(userId, accident, { eventType = 'AUTOMATIC', idempotencyKey, locationAge = false } = {}) {
  const eventResult = await pool.query(`INSERT INTO emergency_events (user_id, accident_id, event_type, idempotency_key, accident_timestamp, latitude, longitude, accident_severity, event_status) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,'PROCESSING') ON CONFLICT (user_id,idempotency_key) DO NOTHING RETURNING id`, [userId, accident.id, eventType, idempotencyKey, accident.detected_at, accident.latitude, accident.longitude, accident.peak_g_force]);
  if (!eventResult.rows[0]) return getEventByKey(userId, idempotencyKey);
  const eventId = eventResult.rows[0].id;
  const { rows } = await pool.query(`SELECT u.full_name,u.phone,v.plate_number,v.model,v.color,COALESCE(es.police_enabled,false) police_enabled,es.police_phone,COALESCE(es.ambulance_enabled,false) ambulance_enabled,es.ambulance_phone,ec.id contact_id,ec.phone contact_phone FROM users u LEFT JOIN vehicles v ON v.id=$2 LEFT JOIN emergency_settings es ON es.user_id=u.id LEFT JOIN emergency_contacts ec ON ec.user_id=u.id AND ec.notification_enabled=true WHERE u.id=$1`, [userId, accident.vehicle_id]);
  const first = rows[0] || {}; const recipients = [];
  if (first.police_enabled) recipients.push({ type: 'POLICE', phone: first.police_phone });
  if (first.ambulance_enabled) recipients.push({ type: 'AMBULANCE', phone: first.ambulance_phone });
  for (const row of rows) if (row.contact_id) recipients.push({ type: 'CONTACT', phone: row.contact_phone });
  const message = buildMessage(first, accident, first.plate_number ? first : null, eventId, locationAge);
  for (const recipient of recipients) {
    const phone = normalizePhone(recipient.phone);
    const inserted = await pool.query(`INSERT INTO notification_logs (event_id,recipient_type,recipient_phone,message) VALUES ($1,$2,$3,$4) ON CONFLICT (event_id,recipient_type,recipient_phone) DO NOTHING RETURNING id`, [eventId, recipient.type, phone || String(recipient.phone || 'invalid'), message]);
    if (!inserted.rows[0]) continue;
    const logId = inserted.rows[0].id;
    if (!phone) { await pool.query(`UPDATE notification_logs SET sending_status='FAILED',error_message='Invalid phone number',updated_at=now() WHERE id=$1`, [logId]); continue; }
    try { const result = await sendViaTextBee(phone, message); await pool.query(`UPDATE notification_logs SET sending_status='QUEUED',provider=$2,provider_message_id=$3,updated_at=now() WHERE id=$1`, [logId, result.provider, result.providerMessageId]); }
    catch (error) { await pool.query(`UPDATE notification_logs SET sending_status='FAILED',error_message=$2,updated_at=now() WHERE id=$1`, [logId, error.message]); }
  }
  await pool.query(`UPDATE emergency_events SET event_status=CASE WHEN NOT EXISTS (SELECT 1 FROM notification_logs WHERE event_id=$1) THEN 'FAILED' WHEN EXISTS (SELECT 1 FROM notification_logs WHERE event_id=$1 AND sending_status='FAILED') THEN 'PARTIAL' WHEN EXISTS (SELECT 1 FROM notification_logs WHERE event_id=$1 AND sending_status IN ('PENDING','QUEUED','SENDING')) THEN 'PROCESSING' ELSE 'COMPLETED' END WHERE id=$1`, [eventId]);
  return getEvent(eventId, userId);
}
async function getEventByKey(userId, key) { const { rows } = await pool.query('SELECT * FROM emergency_events WHERE user_id=$1 AND idempotency_key=$2', [userId, key]); return rows[0] || null; }
async function getEvent(id, userId) { await refreshStatuses(userId, id); const { rows } = await pool.query(`SELECT e.*,COALESCE(json_agg(n ORDER BY n.created_at) FILTER (WHERE n.id IS NOT NULL),'[]') notifications FROM emergency_events e LEFT JOIN notification_logs n ON n.event_id=e.id WHERE e.id=$1 AND e.user_id=$2 GROUP BY e.id`, [id, userId]); return rows[0] || null; }
async function history(userId) { await refreshStatuses(userId); const { rows } = await pool.query(`SELECT e.*,COALESCE(json_agg(n ORDER BY n.created_at) FILTER (WHERE n.id IS NOT NULL),'[]') notifications FROM emergency_events e LEFT JOIN notification_logs n ON n.event_id=e.id WHERE e.user_id=$1 GROUP BY e.id ORDER BY e.created_at DESC LIMIT 100`, [userId]); return rows; }

async function refreshStatuses(userId, eventId = null) {
  if (!env.textbee.enabled || !env.textbee.apiKey || !env.textbee.deviceId) return;
  const params = [userId];
  let filter = 'e.user_id = $1 AND n.provider = \'TEXTBEE\' AND n.provider_message_id IS NOT NULL AND n.sending_status IN (\'QUEUED\', \'SENDING\', \'SENT\')';
  if (eventId != null) { params.push(eventId); filter += ' AND e.id = $2'; }
  const { rows } = await pool.query(`SELECT n.id, n.provider_message_id FROM notification_logs n JOIN emergency_events e ON e.id=n.event_id WHERE ${filter}`, params);
  for (const row of rows) {
    try {
      const response = await fetch(`${env.textbee.baseUrl}/gateway/devices/${env.textbee.deviceId}/sms-batch/${encodeURIComponent(row.provider_message_id)}`, { headers: { 'x-api-key': env.textbee.apiKey }, signal: AbortSignal.timeout(5000) });
      const body = await response.json().catch(() => ({}));
      if (!response.ok) continue;
      const raw = String(body.batch?.status || body.data?.status || body.status || '').toLowerCase();
      const status = raw === 'delivered' ? 'DELIVERED' : raw === 'completed' || raw === 'sent' ? 'SENT' : raw === 'failed' ? 'FAILED' : raw === 'processing' || raw === 'pending' || raw === 'dispatched' ? 'QUEUED' : 'UNKNOWN';
      await pool.query('UPDATE notification_logs SET sending_status=$2, updated_at=now() WHERE id=$1', [row.id, status]);
    } catch (_) { /* status remains queued until the provider can be reached */ }
  }
}

module.exports = { notifyEvent, history, normalizePhone, refreshStatuses };
