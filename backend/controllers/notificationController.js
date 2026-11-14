const service = require('../services/notificationService');
async function history(req, res) { return res.json({ events: await service.history(req.auth.userId) }); }
module.exports = { history };
