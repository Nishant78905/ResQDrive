const { pool } = require('../config/database');

async function list(userId) {
  const { rows } = await pool.query(
    `SELECT id, plate_number, model, color, created_at
     FROM vehicles WHERE user_id = $1 ORDER BY id`,
    [userId]
  );
  return rows;
}

async function create(userId, vehicle) {
  const { rows } = await pool.query(
    `INSERT INTO vehicles (user_id, plate_number, model, color)
     VALUES ($1, $2, $3, $4)
     RETURNING id, plate_number, model, color, created_at`,
    [userId, vehicle.plateNumber, vehicle.model, vehicle.color]
  );
  return rows[0];
}

async function update(userId, id, vehicle) {
  const { rows } = await pool.query(
    `UPDATE vehicles SET plate_number = COALESCE($3, plate_number), model = COALESCE($4, model), color = COALESCE($5, color)
     WHERE user_id = $1 AND id = $2
     RETURNING id, plate_number, model, color, created_at`,
    [userId, id, vehicle.plateNumber, vehicle.model, vehicle.color]
  );
  return rows[0] || null;
}

async function remove(userId, id) {
  const result = await pool.query('DELETE FROM vehicles WHERE user_id = $1 AND id = $2', [userId, id]);
  return result.rowCount > 0;
}

module.exports = { list, create, update, remove };