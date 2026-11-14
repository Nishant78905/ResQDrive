const service = require('../services/emergencySettingsService');
async function get(req, res) { return res.json({ settings: await service.get(req.auth.userId) }); }
async function update(req, res) { return res.json({ settings: await service.update(req.auth.userId, req.body) }); }
module.exports = { get, update };
