const express = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errors');
const controller = require('../controllers/contactController');

const router = express.Router();
const idSchema = Joi.object({ id: Joi.number().integer().positive().required() });
const contactSchema = Joi.object({
  fullName: Joi.string().trim().min(1).max(120),
  relationship: Joi.string().trim().min(1).max(80),
  phone: Joi.string().trim().max(32).allow('', null),
  email: Joi.string().email().max(254).allow('', null),
  preferredChannel: Joi.string().valid('SMS', 'PUSH', 'EMAIL'),
  priority: Joi.number().integer().min(1).max(100),
  notificationEnabled: Joi.boolean()
}).or('fullName', 'relationship', 'phone', 'email', 'preferredChannel', 'priority');
const createSchema = contactSchema.append({
  fullName: contactSchema.extract('fullName').required(),
  relationship: contactSchema.extract('relationship').required(),
  priority: contactSchema.extract('priority').required()
});
const phoneRule = Joi.string().trim().pattern(/^\+?[0-9 ()-]{7,32}$/).allow('', null);
const safeContactSchema = contactSchema.keys({ phone: phoneRule });

router.use(requireAuth);
router.get('/', asyncHandler(controller.list));
router.post('/', validate(createSchema.keys({ phone: phoneRule })), asyncHandler(controller.create));
router.patch('/:id', validate(idSchema, 'params'), validate(safeContactSchema), asyncHandler(controller.update));
router.delete('/:id', validate(idSchema, 'params'), asyncHandler(controller.remove));

module.exports = router;
