const express = require('express');
const Joi = require('joi');
const validate = require('../middleware/validate');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errors');
const controller = require('../controllers/accidentController');

const router = express.Router();
const idSchema = Joi.object({ id: Joi.number().integer().positive().required() });
const incidentSchema = Joi.object({
  vehicleId: Joi.number().integer().positive().allow(null),
  lat: Joi.number().min(-90).max(90).required(),
  lng: Joi.number().min(-180).max(180).required(),
  peakG: Joi.number().min(0).max(100).required(),
  gyroData: Joi.alternatives().try(Joi.object(), Joi.array()).default({}),
  timestamp: Joi.date().iso().required(),
  deferSos: Joi.boolean().default(false),
  eventType: Joi.string().valid('AUTOMATIC', 'MANUAL').default('AUTOMATIC'),
  idempotencyKey: Joi.string().trim().max(120)
});
const locationSchema = Joi.object({ lat: Joi.number().min(-90).max(90).required(), lng: Joi.number().min(-180).max(180).required() });

router.use(requireAuth);
router.post('/', validate(incidentSchema), asyncHandler(controller.create));
router.post('/manual', validate(incidentSchema.fork(['lat', 'lng', 'timestamp'], field => field.required()).keys({ deferSos: Joi.valid(false).default(false), eventType: Joi.valid('MANUAL').default('MANUAL') })), asyncHandler(controller.create));
router.patch('/:id/cancel', validate(idSchema, 'params'), asyncHandler(controller.cancel));
router.post('/:id/escalate', validate(idSchema, 'params'), validate(locationSchema), asyncHandler(controller.escalate));
router.get('/history', asyncHandler(controller.history));

module.exports = router;
