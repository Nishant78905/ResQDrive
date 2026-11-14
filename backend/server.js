const app = require('./app');
const { pool } = require('./config/database');
const env = require('./config/env');

const server = app.listen(env.port, () => {
  console.info(`RESQDRIVE API listening on port ${env.port}`);
});

async function shutdown(signal) {
  console.info(`${signal} received; shutting down`);
  server.close(async error => {
    await pool.end();
    if (error) {
      console.error(error);
      process.exitCode = 1;
    }
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));