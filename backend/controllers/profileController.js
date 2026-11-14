const service = require('../services/profileService');
const { HttpError } = require('../middleware/errors');
async function get(req, res) { const profile = await service.get(req.auth.userId); if (!profile) throw new HttpError(404, 'Profile not found'); return res.json({ profile }); }
async function update(req, res) { const profile = await service.update(req.auth.userId, req.body); if (!profile) throw new HttpError(404, 'Profile not found'); return res.json({ profile }); }
module.exports = { get, update };
