const service = require('../services/vehicleService');
const { HttpError } = require('../middleware/errors');

async function list(req, res) { return res.json({ vehicles: await service.list(req.auth.userId) }); }
async function create(req, res) { return res.status(201).json({ vehicle: await service.create(req.auth.userId, req.body) }); }
async function update(req, res) {
  const vehicle = await service.update(req.auth.userId, req.params.id, req.body);
  if (!vehicle) throw new HttpError(404, 'Vehicle not found');
  return res.json({ vehicle });
}
async function remove(req, res) {
  if (!await service.remove(req.auth.userId, req.params.id)) throw new HttpError(404, 'Vehicle not found');
  return res.status(204).end();
}

module.exports = { list, create, update, remove };