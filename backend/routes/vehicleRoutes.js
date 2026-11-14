const express = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errors');
const controller = require('../controllers/vehicleController');

const router = express.Router();
const idSchema = Joi.object({ id: Joi.number().integer().positive().required() });
const vehicleSchema = Joi.object({
  plateNumber: Joi.string().trim().min(1).max(24),
  model: Joi.string().trim().min(1).max(120),
  color: Joi.string().trim().min(1).max(40)
}).or('plateNumber', 'model', 'color');
const createSchema = vehicleSchema.append({
  plateNumber: vehicleSchema.extract('plateNumber').required(),
  model: vehicleSchema.extract('model').required(),
  color: vehicleSchema.extract('color').required()
});

router.use(requireAuth);
router.get('/', asyncHandler(controller.list));
router.post('/', validate(createSchema), asyncHandler(controller.create));
router.patch('/:id', validate(idSchema, 'params'), validate(vehicleSchema), asyncHandler(controller.update));
router.delete('/:id', validate(idSchema, 'params'), asyncHandler(controller.remove));

module.exports = router;