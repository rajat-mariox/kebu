import winston from 'winston';
import { getConfig } from './config';

const config = getConfig();

const logFormat = winston.format.combine(
  winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
  winston.format.errors({ stack: true }),
  winston.format.printf(({ timestamp, level, message, ...meta }) => {
    let metaStr = '';
    if (Object.keys(meta).length > 0) {
      metaStr = ' ' + JSON.stringify(meta);
    }
    return `${timestamp} [${level.toUpperCase()}] ${message}${metaStr}`;
  })
);

export const logger = winston.createLogger({
  level: config.logLevel || 'info',
  format: logFormat,
  transports: [
    new winston.transports.Console({
      format: winston.format.combine(
        winston.format.colorize(),
        logFormat
      )
    })
  ]
});

export const createLogger = (service: string) => {
  return {
    info: (message: string, meta?: Record<string, any>) => 
      logger.info(`[${service}] ${message}`, meta),
    error: (message: string, meta?: Record<string, any>) => 
      logger.error(`[${service}] ${message}`, meta),
    warn: (message: string, meta?: Record<string, any>) => 
      logger.warn(`[${service}] ${message}`, meta),
    debug: (message: string, meta?: Record<string, any>) => 
      logger.debug(`[${service}] ${message}`, meta),
  };
};
