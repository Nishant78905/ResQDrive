const express = require('express');
const Joi = require('joi');
const { requireAuth, requireRole } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errors');
const validate = require('../middleware/validate');
const controller = require('../controllers/accidentController');

const router = express.Router();
const idSchema = Joi.object({ id: Joi.number().integer().positive().required() });
router.use(requireAuth, requireRole('DISPATCHER', 'ADMIN'));
router.get('/active', asyncHandler(controller.activeForDispatch));
router.patch('/:id/resolve', validate(idSchema, 'params'), asyncHandler(controller.resolve));

module.exports = router;