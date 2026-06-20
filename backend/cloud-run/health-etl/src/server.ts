import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import * as winston from 'winston';
import * as cron from 'node-cron';
import { ETLService } from './services/ETLService';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.Console()
  ]
});

const app = express();
const etlService = new ETLService();

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Manual ETL trigger endpoint
app.post('/etl/daily', async (req, res) => {
  try {
    const { date } = req.body;
    logger.info(`Manual ETL trigger for date: ${date || 'yesterday'}`);
    
    await etlService.runDailyETL(date);
    
    res.json({ 
      success: true, 
      message: 'Daily ETL completed successfully',
      date: date || 'yesterday'
    });
  } catch (error) {
    logger.error('Manual ETL failed:', error);
    res.status(500).json({ 
      success: false, 
      error: 'ETL job failed',
      details: error instanceof Error ? error.message : 'Unknown error'
    });
  }
});

// ETL status endpoint
app.get('/etl/status', async (req, res) => {
  try {
    // This would check the status of recent ETL jobs
    // For now, just return a simple status
    res.json({
      status: 'operational',
      lastRun: new Date().toISOString(),
      nextScheduledRun: getNextScheduledRun()
    });
  } catch (error) {
    logger.error('Status check failed:', error);
    res.status(500).json({ error: 'Status check failed' });
  }
});

// Schedule daily ETL job to run at 2 AM UTC
cron.schedule('0 2 * * *', async () => {
  logger.info('Starting scheduled daily ETL job');
  try {
    await etlService.runDailyETL();
    logger.info('Scheduled daily ETL completed successfully');
  } catch (error) {
    logger.error('Scheduled daily ETL failed:', error);
  }
}, {
  timezone: "UTC"
});

function getNextScheduledRun(): string {
  const now = new Date();
  const tomorrow = new Date(now);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);
  tomorrow.setUTCHours(2, 0, 0, 0);
  
  // If it's already past 2 AM today, next run is tomorrow
  if (now.getUTCHours() >= 2) {
    return tomorrow.toISOString();
  } else {
    // Next run is today at 2 AM
    const today = new Date(now);
    today.setUTCHours(2, 0, 0, 0);
    return today.toISOString();
  }
}

const PORT = process.env.PORT || 8080;

app.listen(PORT, () => {
  logger.info(`Health ETL service started on port ${PORT}`);
  logger.info(`Daily ETL scheduled to run at 2 AM UTC`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  process.exit(0);
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  process.exit(0);
});