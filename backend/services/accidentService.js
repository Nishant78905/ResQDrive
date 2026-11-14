const { pool, withTransaction } = require('../config/database');
const { notifyEvent } = require('./notificationService');
const { HttpError } = require('../middleware/errors');
const env = require('../config/env');

async function create(userId, incident) {
  if (incident.idempotencyKey) {
    const existing = await pool.query('SELECT accident_id FROM emergency_events WHERE user_id = $1 AND idempotency_key = $2', [userId, incident.idempotencyKey]);
    if (existing.rows[0]) return (await pool.query('SELECT id, user_id, vehicle_id, latitude, longitude, peak_g_force, gyro_data, detected_at, status FROM accidents WHERE id = $1', [existing.rows[0].accident_id])).rows[0];
  }
  const recent = await pool.query(`SELECT 1 FROM accidents WHERE user_id=$1 AND created_at > now() - ($2 * interval '1 second') AND status IN ('DETECTED','SOS_SENT') LIMIT 1`, [userId, env.sosRateLimitSeconds]);
  if (recent.rows[0] && !incident.deferSos) throw new HttpError(429, 'An emergency event was already recorded recently');
  const result = await withTransaction(async client => {
    const call = await client.query(
      'CALL create_accident_with_sos($1, $2, $3, $4, $5, $6::jsonb, $7, $8)',
      [userId, incident.vehicleId || null, incident.lat, incident.lng, incident.peakG, JSON.stringify(incident.gyroData || {}), incident.timestamp, null]
    );
    const accidentId = call.rows[0]?.p_accident_id;
    if (!accidentId) throw new Error('create_accident_with_sos returned no accident id');

    if (!incident.deferSos) {
      await client.query("UPDATE accidents SET status = 'SOS_SENT' WHERE id = $1", [accidentId]);
    }
    const alerts = await client.query(
      `SELECT sa.accident_id, sa.channel, ec.id AS contact_id, ec.phone, ec.email
       FROM sos_alerts AS sa
       LEFT JOIN emergency_contacts AS ec ON ec.id = sa.contact_id
       WHERE sa.accident_id = $1 ORDER BY ec.priority`,
      [accidentId]
    );
    const accident = await client.query(
      `SELECT id, user_id, vehicle_id, latitude, longitude, peak_g_force, gyro_data, detected_at, status
       FROM accidents WHERE id = $1`,
      [accidentId]
    );
    return { accident: accident.rows[0], alerts: alerts.rows };
  });

  if (!incident.deferSos) {
    await notifyEvent(userId, result.accident, { eventType: incident.eventType || 'AUTOMATIC', idempotencyKey: incident.idempotencyKey || `accident:${result.accident.id}` });
  }
  return result.accident;
}

async function escalate(userId, id, location) {
  const result = await withTransaction(async client => {
    const { rows } = await client.query(
      `UPDATE accidents SET latitude = $3, longitude = $4, status = 'SOS_SENT'
       WHERE id = $1 AND user_id = $2 AND status = 'DETECTED'
       RETURNING id, user_id, vehicle_id, latitude, longitude, peak_g_force, gyro_data, detected_at, status`,
      [id, userId, location.lat, location.lng]
    );
    if (!rows[0]) throw new HttpError(404, 'Active accident not found or already cancelled');
    const alerts = await client.query(
      `SELECT sa.accident_id, sa.channel, ec.id AS contact_id, ec.phone, ec.email
       FROM sos_alerts AS sa LEFT JOIN emergency_contacts AS ec ON ec.id = sa.contact_id
       WHERE sa.accident_id = $1 AND sa.delivery_status = 'PENDING' ORDER BY ec.priority`,
      [id]
    );
    return { accident: rows[0], alerts: alerts.rows };
  });

  await notifyEvent(userId, result.accident, { eventType: 'AUTOMATIC', idempotencyKey: `accident:${id}` });
  return result.accident;
}

async function cancel(userId, id) {
  return withTransaction(async client => {
    const { rows } = await client.query(
      `UPDATE accidents SET status = 'CANCELLED_BY_USER'
       WHERE id = $1 AND user_id = $2 AND status = 'DETECTED'
       RETURNING id, status, updated_at`,
      [id, userId]
    );
    if (!rows[0]) throw new HttpError(404, 'Active accident not found or already escalated');
    await client.query(
      "UPDATE sos_alerts SET delivery_status = 'CANCELLED' WHERE accident_id = $1 AND delivery_status = 'PENDING'",
      [id]
    );
    return rows[0];
  });
}

async function history(userId) {
  const { rows } = await pool.query(
    `SELECT a.id, a.detected_at, a.status, a.latitude, a.longitude, a.peak_g_force,
            v.plate_number, v.model AS vehicle_model
     FROM accidents AS a LEFT JOIN vehicles AS v ON v.id = a.vehicle_id
     WHERE a.user_id = $1 ORDER BY a.detected_at DESC LIMIT 100`,
    [userId]
  );
  return rows;
}

async function activeForDispatch() {
  const { rows } = await pool.query('SELECT * FROM dispatch_active_accidents ORDER BY detected_at ASC');
  return rows;
}

async function resolve(id) {
  const { rows } = await pool.query(
    `UPDATE accidents SET status = 'RESOLVED'
     WHERE id = $1 AND status IN ('DETECTED', 'SOS_SENT')
     RETURNING id, status, updated_at`,
    [id]
  );
  if (!rows[0]) throw new HttpError(404, 'Active accident not found or already resolved');
  return rows[0];
}

module.exports = { create, escalate, cancel, history, activeForDispatch, resolve };
