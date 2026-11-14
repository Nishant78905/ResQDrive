const env = require('../config/env');

function errorHandler(error, req, res, next) {
  if (res.headersSent) return next(error);

  let status = error.status || 500;
  let message = error.message || 'Internal server error';
  if (error.code === '23505') {
    status = 409;
    message = 'A record with those details already exists';
  } else if (error.code === '23503') {
    status = 400;
    message = 'A referenced record does not exist';
  }

  if (status >= 500) console.error(error);
  const body = { error: message };
  if (error.details) body.details = error.details;
  if (env.nodeEnv !== 'production' && status >= 500) body.requestId = req.id;
  return res.status(status).json(body);
}

module.exports = errorHandler;