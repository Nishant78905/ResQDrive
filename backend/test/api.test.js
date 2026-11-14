process.env.NODE_ENV = 'test';
process.env.DATABASE_URL ||= 'postgresql://postgres:postgres@localhost:5432/resqdrive_test';
process.env.JWT_SECRET ||= 'test-only-signing-key-that-is-at-least-32-characters-long';

const request = require('supertest');
const app = require('../app');

describe('RESQDRIVE API', () => {
  test('health endpoint reports the service is ready', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });

  test('rejects invalid registration before database access', async () => {
    const response = await request(app).post('/api/auth/register').send({ email: 'not-an-email', password: 'short' });
    expect(response.status).toBe(400);
    expect(response.body.error).toBe('Request validation failed');
    expect(response.body.details.length).toBeGreaterThan(0);
  });

  test('protects driver contact routes', async () => {
    const response = await request(app).get('/api/contacts');
    expect(response.status).toBe(401);
    expect(response.body.error).toBe('Authentication required');
  });

  test('protects dispatcher routes', async () => {
    const response = await request(app).get('/api/dispatch/active');
    expect(response.status).toBe(401);
    expect(response.body.error).toBe('Authentication required');
  });

  test('returns a consistent not-found response', async () => {
    const response = await request(app).get('/api/not-a-route');
    expect(response.status).toBe(404);
    expect(response.body.error).toBe('Route not found');
  });
});