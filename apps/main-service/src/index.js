const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const healthRoutes = require('./routes/health');
const catalogRoutes = require('./routes/catalog');
const orderRoutes = require('./routes/orders');
const fileRoutes = require('./routes/files');
const { errorHandler, notFoundHandler } = require('./middleware/errorHandler');
const { circuitBreakerMiddleware, circuitBreakerRouter } = require('./middleware/circuitBreaker');
const redisClient = require('./config/redis');

const app = express();
const PORT = process.env.PORT || 3001;

// 보안 미들웨어
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

// CORS 설정
app.use(cors({
  origin: process.env.FRONTEND_URL || 'http://localhost:3000',
  credentials: true,
}));

// 압축 미들웨어
app.use(compression());

// 로깅 미들웨어
app.use(morgan('combined'));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15분
  max: 100, // 최대 100 요청
  message: {
    error: 'Too many requests from this IP, please try again later.',
  },
});
app.use(limiter);

// Body parsing 미들웨어
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Circuit Breaker 미들웨어
app.use(circuitBreakerMiddleware);

// 라우트 설정
app.use('/health', healthRoutes);
app.use('/api/catalog', catalogRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/files', fileRoutes);
app.use('/api/admin', circuitBreakerRouter);

// 루트 경로
app.get('/', (req, res) => {
  res.json({
    service: 'Main Service (API Gateway)',
    version: process.env.npm_package_version || '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
  });
});

// 에러 핸들링 미들웨어
app.use(notFoundHandler);
app.use(errorHandler);

// 서버 시작
const server = app.listen(PORT, () => {
  console.log(`Main Service running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    redisClient.quit();
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
    redisClient.quit();
    process.exit(0);
  });
});

module.exports = app;