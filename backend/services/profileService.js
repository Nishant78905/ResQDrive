const { pool } = require('../config/database');

async function get(userId) {
  const { rows } = await pool.query(`SELECT id, email, full_name, phone, created_at FROM users WHERE id = $1`, [userId]);
  return rows[0] || null;
}

async function update(userId, values) {
  const { rows } = await pool.query(
    `UPDATE users SET full_name = COALESCE($2, full_name), phone = COALESCE($3, phone), updated_at = now()
     WHERE id = $1 RETURNING id, email, full_name, phone, created_at`,
    [userId, values.fullName, values.phone]
  );
  return rows[0] || null;
}

module.exports = { get, update };
