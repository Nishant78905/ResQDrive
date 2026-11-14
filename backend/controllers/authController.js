const authService = require('../services/authService');

async function register(req, res) {
  const user = await authService.register(req.body);
  return res.status(201).json({ user });
}

async function login(req, res) {
  return res.json(await authService.login(req.body));
}

async function dispatchLogin(req, res) {
  return res.json(await authService.login(req.body, 'dispatch_users'));
}
async function logout(req, res) { await authService.revoke(req.get('authorization').slice(7)); return res.status(204).end(); }

module.exports = { register, login, dispatchLogin, logout };
