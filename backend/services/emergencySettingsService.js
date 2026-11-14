
const { pool } = require('../config/database');

async function get(userId) {
  // First, ensure that the user has an emergency settings row.
  await pool.query(
    `INSERT INTO emergency_settings (user_id)
     VALUES ($1)
     ON CONFLICT (user_id) DO NOTHING`,
    [userId]
  );

  // Then retrieve the user's emergency settings.
  const { rows } = await pool.query(
    `SELECT user_id, police_enabled, police_phone,
            ambulance_enabled, ambulance_phone, updated_at
     FROM emergency_settings
     WHERE user_id = $1`,
    [userId]
  );

  return rows[0];
}

async function update(userId, settings) {
  const { rows } = await pool.query(
    `INSERT INTO emergency_settings
       (user_id, police_enabled, police_phone,
        ambulance_enabled, ambulance_phone)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id)
     DO UPDATE SET
       police_enabled = $2,
       police_phone = $3,
       ambulance_enabled = $4,
       ambulance_phone = $5,
       updated_at = now()
     RETURNING user_id, police_enabled, police_phone,
               ambulance_enabled, ambulance_phone, updated_at`,
    [
      userId,
      settings.policeEnabled,
      settings.policePhone || null,
      settings.ambulanceEnabled,
      settings.ambulancePhone || null
    ]
  );

  return rows[0];
}

module.exports = { get, update };
