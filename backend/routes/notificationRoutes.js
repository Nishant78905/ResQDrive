const express = require('express');
const { requireAuth } = require('../middleware/auth');
const { asyncHandler } = require('../middleware/errors');
const controller = require('../controllers/notificationController');
const router = express.Router(); router.use(requireAuth); router.get('/history', asyncHandler(controller.history));
module.exports = router;
