const jwt = require('jsonwebtoken');
const env = require('../config/env');
const { HttpError } = require('./errors');
const { pool } = require('../config/database');

async function requireAuth(req, res, next) {
  const authorization = req.get('authorization');
  if (!authorization || !authorization.startsWith('Bearer ')) {
    return next(new HttpError(401, 'Authentication required'));
  }

  try {
    const payload = jwt.verify(authorization.slice(7), env.jwtSecret);
    const revoked = await pool.query('SELECT 1 FROM revoked_tokens WHERE jti = $1 AND expires_at > now()', [payload.jti || authorization.slice(7)]);
    if (revoked.rows[0]) return next(new HttpError(401, 'Token has been revoked'));
    req.auth = { userId: payload.sub, role: payload.role };
    return next();
  } catch {
    return next(new HttpError(401, 'Invalid or expired token'));
  }
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.auth || !roles.includes(req.auth.role)) {
      return next(new HttpError(403, 'Insufficient permissions'));
    }
    return next();
  };
}

module.exports = { requireAuth, requireRole };
