require('dotenv').config();

const Joi = require('joi');

const schema = Joi.object({
  NODE_ENV: Joi.string().valid('development', 'test', 'production').default('development'),
  PORT: Joi.number().port().default(3000),
  DATABASE_URL: Joi.string().uri({ scheme: ['postgres', 'postgresql'] }).required(),
  JWT_SECRET: Joi.string().min(32).required(),
  JWT_EXPIRES_IN: Joi.string().default('1h'),
  CORS_ORIGIN: Joi.string().default('http://localhost:5173'),
  PG_POOL_MAX: Joi.number().integer().min(1).max(100).default(10),
  TEXTBEE_ENABLED: Joi.boolean().truthy('1', 'true').falsy('0', 'false').default(false),
  TEXTBEE_API_KEY: Joi.string().allow('').default(''),
  TEXTBEE_DEVICE_ID: Joi.string().allow('').default(''),
  TEXTBEE_BASE_URL: Joi.string().uri().default('https://api.textbee.dev/api/v1'),
  TEXTBEE_MAX_RETRIES: Joi.number().integer().min(0).max(5).default(2),
  SOS_RATE_LIMIT_SECONDS: Joi.number().integer().min(1).default(60)
}).unknown(true);

const { error, value } = schema.validate(process.env, { convert: true });
if (error) {
  throw new Error(`Invalid environment configuration: ${error.message}`);
}

module.exports = {
  nodeEnv: value.NODE_ENV,
  port: value.PORT,
  databaseUrl: value.DATABASE_URL,
  jwtSecret: value.JWT_SECRET,
  jwtExpiresIn: value.JWT_EXPIRES_IN,
  corsOrigins: value.CORS_ORIGIN.split(',').map(origin => origin.trim()).filter(Boolean),
  poolMax: value.PG_POOL_MAX,
  textbee: { enabled: value.TEXTBEE_ENABLED, apiKey: value.TEXTBEE_API_KEY, deviceId: value.TEXTBEE_DEVICE_ID, baseUrl: value.TEXTBEE_BASE_URL, maxRetries: value.TEXTBEE_MAX_RETRIES },
  sosRateLimitSeconds: value.SOS_RATE_LIMIT_SECONDS
};
