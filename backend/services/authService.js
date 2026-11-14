const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { pool } = require('../config/database');
const env = require('../config/env');
const { HttpError } = require('../middleware/errors');

async function register({ email, password, fullName, phone }) {
  const passwordHash = await bcrypt.hash(password, 12);
  const { rows } = await pool.query(
    `INSERT INTO users (email, password_hash, full_name, phone)
     VALUES ($1, $2, $3, $4)
     RETURNING id, email, full_name, phone, created_at`,
    [email.toLowerCase(), passwordHash, fullName, phone || null]
  );
  return rows[0];
}

async function login({ email, password }, table = 'users', role = 'DRIVER') {
  const allowedTables = { users: 'users', dispatch_users: 'dispatch_users' };
  const tableName = allowedTables[table];
  const { rows } = await pool.query(
    `SELECT id, email, password_hash, full_name${table === 'dispatch_users' ? ', role, is_active' : ''}
     FROM ${tableName} WHERE lower(email) = lower($1) OR (${table === 'users' ? 'phone = $1' : 'false'})`,
    [email]
  );
  const account = rows[0];
  const validPassword = account && await bcrypt.compare(password, account.password_hash);
  if (!validPassword || (table === 'dispatch_users' && !account.is_active)) {
    throw new HttpError(401, 'Email or password is incorrect');
  }

  const token = jwt.sign({ sub: String(account.id), role: table === 'dispatch_users' ? account.role : role }, env.jwtSecret, {
    expiresIn: env.jwtExpiresIn
  });
  return {
    token,
    user: { id: account.id, email: account.email, fullName: account.full_name }
  };
}

async function revoke(token) {
  const payload = jwt.verify(token, env.jwtSecret);
  await pool.query('INSERT INTO revoked_tokens (jti, expires_at) VALUES ($1, to_timestamp($2)) ON CONFLICT DO NOTHING', [payload.jti || token, payload.exp]);
}

module.exports = { register, login, revoke };
