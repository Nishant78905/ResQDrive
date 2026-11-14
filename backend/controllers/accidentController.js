const service = require('../services/accidentService');

async function create(req, res) {
  const accident = await service.create(req.auth.userId, { ...req.body, idempotencyKey: req.get('Idempotency-Key') || req.body.idempotencyKey });
  return res.status(201).json({ accident });
}

async function cancel(req, res) {
  return res.json({ accident: await service.cancel(req.auth.userId, req.params.id) });
}

async function escalate(req, res) {
  return res.json({ accident: await service.escalate(req.auth.userId, req.params.id, req.body) });
}

async function history(req, res) {
  return res.json({ accidents: await service.history(req.auth.userId) });
}

async function activeForDispatch(req, res) {
  return res.json({ accidents: await service.activeForDispatch() });
}

async function resolve(req, res) {
  return res.json({ accident: await service.resolve(req.params.id) });
}

module.exports = { create, escalate, cancel, history, activeForDispatch, resolve };
