process.env.NODE_ENV = 'test';

const runDatabaseTests = process.env.DB_TESTS === '1' ? describe : describe.skip;

runDatabaseTests('PostgreSQL accident procedure and audit trigger', () => {
  let pool;
  let client;
  let userId;
  let vehicleId;
  let contactId;

  beforeAll(async () => {
    ({ pool } = require('../config/database'));
    client = await pool.connect();
    await client.query('BEGIN');
    const suffix = `${Date.now()}-${Math.floor(Math.random() * 100000)}`;
    const user = await client.query(
      `INSERT INTO users (email, password_hash, full_name)
       VALUES ($1, 'test-placeholder', 'DB Test Driver') RETURNING id`,
      [`db-test-${suffix}@example.test`]
    );
    userId = user.rows[0].id;
    const vehicle = await client.query(
      `INSERT INTO vehicles (user_id, plate_number, model, color)
       VALUES ($1, $2, 'Test Vehicle', 'Red') RETURNING id`,
      [userId, `DB-${suffix}`]
    );
    vehicleId = vehicle.rows[0].id;
    const contact = await client.query(
      `INSERT INTO emergency_contacts (user_id, full_name, relationship, phone, preferred_channel, priority)
       VALUES ($1, 'Test Contact', 'Friend', '+1-555-0000', 'SMS', 1) RETURNING id`,
      [userId]
    );
    contactId = contact.rows[0].id;
  });

  afterAll(async () => {
    if (client) {
      await client.query('ROLLBACK');
      client.release();
    }
    if (pool) await pool.end();
  });

  test('creates an accident and contact alert atomically and audits insert/update', async () => {
    const call = await client.query(
      'CALL create_accident_with_sos($1, $2, $3, $4, $5, $6::jsonb, $7, $8)',
      [userId, vehicleId, 37.7749, -122.4194, 4.25, JSON.stringify({ x: 0.2, y: 4.1, z: 0.1 }), new Date(), null]
    );
    const accidentId = call.rows[0].p_accident_id;

    const alerts = await client.query('SELECT id, contact_id, channel, delivery_status FROM sos_alerts WHERE accident_id = $1', [accidentId]);
    expect(alerts.rowCount).toBe(1);
    expect(String(alerts.rows[0].contact_id)).toBe(String(contactId));
    expect(alerts.rows[0].channel).toBe('SMS');
    expect(alerts.rows[0].delivery_status).toBe('PENDING');

    await client.query("UPDATE accidents SET status = 'SOS_SENT' WHERE id = $1", [accidentId]);
    const audit = await client.query(
      "SELECT action FROM audit_log WHERE table_name = 'accidents' AND record_id = $1 ORDER BY id",
      [accidentId]
    );
    expect(audit.rows.map(row => row.action)).toEqual(['INSERT', 'UPDATE']);
  });
});