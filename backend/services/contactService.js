const { pool } = require('../config/database');

async function list(userId) {
  const { rows } = await pool.query(
    `SELECT id, full_name, relationship, phone, email, preferred_channel, priority, notification_enabled, created_at
     FROM emergency_contacts WHERE user_id = $1 ORDER BY priority, id`,
    [userId]
  );
  return rows;
}

async function create(userId, contact) {
  const nextPriority = await pool.query('SELECT COALESCE(MAX(priority), 0) + 1 AS priority FROM emergency_contacts WHERE user_id = $1', [userId]);
  const priority = Math.max(Number(contact.priority) || 1, Number(nextPriority.rows[0].priority));
  const { rows } = await pool.query(
    `INSERT INTO emergency_contacts (user_id, full_name, relationship, phone, email, preferred_channel, priority, notification_enabled)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING id, full_name, relationship, phone, email, preferred_channel, priority, notification_enabled, created_at`,
    [userId, contact.fullName, contact.relationship, contact.phone || null, contact.email || null, contact.preferredChannel, priority, contact.notificationEnabled ?? false]
  );
  return rows[0];
}

async function update(userId, id, contact) {
  const { rows } = await pool.query(
    `UPDATE emergency_contacts
     SET full_name = COALESCE($3, full_name), relationship = COALESCE($4, relationship),
         phone = COALESCE($5, phone), email = COALESCE($6, email),
         preferred_channel = COALESCE($7, preferred_channel), priority = COALESCE($8, priority)
         , notification_enabled = COALESCE($9, notification_enabled)
     WHERE user_id = $1 AND id = $2
     RETURNING id, full_name, relationship, phone, email, preferred_channel, priority, notification_enabled, created_at`,
    [userId, id, contact.fullName, contact.relationship, contact.phone, contact.email, contact.preferredChannel, contact.priority, contact.notificationEnabled]
  );
  return rows[0] || null;
}

async function remove(userId, id) {
  const result = await pool.query('DELETE FROM emergency_contacts WHERE user_id = $1 AND id = $2', [userId, id]);
  return result.rowCount > 0;
}

module.exports = { list, create, update, remove };
