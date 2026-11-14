const express = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { asyncHandler } = require('../middleware/errors');
const controller = require('../controllers/authController');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
const loginSchema = Joi.object({ email: Joi.string().email().max(254).required(), password: Joi.string().min(8).max(128).required() });

router.post('/register', validate(Joi.object({
  email: Joi.string().email().max(254).required(),
  password: Joi.string().min(8).max(128).required(),
  fullName: Joi.string().trim().min(1).max(120).required(),
  phone: Joi.string().trim().pattern(/^\+?[0-9 ()-]{7,32}$/).allow('', null)
})), asyncHandler(controller.register));
router.post('/login', validate(Joi.object({ email: Joi.string().trim().max(254).required(), password: Joi.string().min(8).max(128).required() })), asyncHandler(controller.login));
router.post('/logout', requireAuth, asyncHandler(controller.logout));

module.exports = router;
