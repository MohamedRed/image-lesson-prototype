import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import { logger } from './utils/logger';
import { healthAnalyticsRouter } from './routes/analytics';
import { insightGenerationRouter } from './routes/insights';
import { leaderboardRouter } from './routes/leaderboard';
import { scheduledTasksRouter } from './routes/scheduled';
import { errorHandler } from './middleware/errorHandler';
import { authMiddleware } from './middleware/auth';

const app = express();
const port = process.env.PORT || 8080;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000'],
  credentials: true
}));

// Request parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Logging middleware
app.use((req, res, next) => {
  logger.info(`${req.method} ${req.path}`, {
    userAgent: req.get('user-agent'),
    ip: req.ip
  });
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    service: 'health-analytics-worker',
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Protected routes
app.use('/analytics', authMiddleware, healthAnalyticsRouter);
app.use('/insights', authMiddleware, insightGenerationRouter);
app.use('/leaderboard', authMiddleware, leaderboardRouter);
app.use('/scheduled', scheduledTasksRouter); // Internal only, no auth needed

// Error handling
app.use(errorHandler);

// Start server
app.listen(port, () => {
  logger.info(`Health Analytics Worker started on port ${port}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('Received SIGTERM, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('Received SIGINT, shutting down gracefully');
  process.exit(0);
});

export default app;