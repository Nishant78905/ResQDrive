const service = require('../services/contactService');
const { HttpError } = require('../middleware/errors');

async function list(req, res) { return res.json({ contacts: await service.list(req.auth.userId) }); }
async function create(req, res) { return res.status(201).json({ contact: await service.create(req.auth.userId, req.body) }); }
async function update(req, res) {
  const contact = await service.update(req.auth.userId, req.params.id, req.body);
  if (!contact) throw new HttpError(404, 'Contact not found');
  return res.json({ contact });
}
async function remove(req, res) {
  if (!await service.remove(req.auth.userId, req.params.id)) throw new HttpError(404, 'Contact not found');
  return res.status(204).end();
}

module.exports = { list, create, update, remove };