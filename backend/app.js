const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const { rateLimit } = require('express-rate-limit');
const env = require('./config/env');
const { asyncHandler } = require('./middleware/errors');
const errorHandler = require('./middleware/errorHandler');
const authRoutes = require('./routes/authRoutes');
const contactRoutes = require('./routes/contactRoutes');
const vehicleRoutes = require('./routes/vehicleRoutes');
const accidentRoutes = require('./routes/accidentRoutes');
const dispatchRoutes = require('./routes/dispatchRoutes');
const profileRoutes = require('./routes/profileRoutes');
const emergencySettingsRoutes = require('./routes/emergencySettingsRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const authController = require('./controllers/authController');
const validate = require('./middleware/validate');
const Joi = require('joi');

const app = express();
app.disable('x-powered-by');
app.use(helmet());
app.use(cors({ origin: env.corsOrigins }));
app.use(express.json({ limit: '64kb' }));
app.use('/api', rateLimit({ windowMs: 15 * 60 * 1000, limit: 120, standardHeaders: 'draft-7', legacyHeaders: false }));
app.get('/health', (req, res) => res.json({ status: 'ok' }));
app.use('/api/auth', authRoutes);
app.post('/api/dispatch/login', validate(Joi.object({
  email: Joi.string().email().max(254).required(),
  password: Joi.string().min(8).max(128).required()
})), asyncHandler(authController.dispatchLogin));
app.use('/api/contacts', contactRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/emergency-settings', emergencySettingsRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/accidents', accidentRoutes);
app.use('/api/dispatch', dispatchRoutes);
app.use((req, res) => res.status(404).json({ error: 'Route not found' }));
app.use(errorHandler);

module.exports = app;
