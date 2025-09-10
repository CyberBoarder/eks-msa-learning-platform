const express = require('express');
const axios = require('axios');
const { checkRedisHealth, cacheHelpers } = require('../config/redis');

const router = express.Router();

// 서비스 URL 설정
const CATALOG_SERVICE_URL = process.env.CATALOG_SERVICE_URL || 'http://catalog-service:8000';
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://order-service:8080';

// 기본 헬스체크
router.get('/', async (req, res) => {
  const healthCheck = {
    service: 'Main Service',
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    memory: process.memoryUsage(),
  };

  res.status(200).json(healthCheck);
});

// 상세 헬스체크 (모든 의존성 포함)
router.get('/detailed', async (req, res) => {
  const startTime = Date.now();
  
  try {
    // 각 서비스 헬스체크를 병렬로 실행
    const [catalogHealth, orderHealth, redisHealth] = await Promise.allSettled([
      checkServiceHealth(CATALOG_SERVICE_URL),
      checkServiceHealth(ORDER_SERVICE_URL),
      checkRedisHealth()
    ]);

    // Redis 통계 가져오기
    const redisStats = await cacheHelpers.getStats();
    const hitRate = redisStats ? 
      Math.round((redisStats.keyspace_hits / (redisStats.keyspace_hits + redisStats.keyspace_misses)) * 100) || 0 
      : 0;

    const healthData = {
      service: 'Main Service',
      status: 'healthy',
      timestamp: new Date().toISOString(),
      responseTime: Date.now() - startTime,
      services: [
        {
          name: 'Frontend',
          status: 'healthy', // Frontend는 정적 파일이므로 항상 healthy
          responseTime: 0
        },
        {
          name: 'Main Service',
          status: 'healthy',
          responseTime: Date.now() - startTime
        },
        {
          name: 'Catalog Service',
          status: catalogHealth.status === 'fulfilled' ? catalogHealth.value.status : 'unhealthy',
          responseTime: catalogHealth.status === 'fulfilled' ? catalogHealth.value.responseTime : 0
        },
        {
          name: 'Order Service',
          status: orderHealth.status === 'fulfilled' ? orderHealth.value.status : 'unhealthy',
          responseTime: orderHealth.status === 'fulfilled' ? orderHealth.value.responseTime : 0
        }
      ],
      database: {
        status: 'connected', // 실제로는 각 서비스에서 확인
        connections: 12 // 목업 데이터
      },
      cache: {
        status: redisHealth.status,
        hitRate: hitRate,
        connections: redisStats ? redisStats.connected_clients : 0,
        memory: redisStats ? Math.round(redisStats.used_memory / 1024 / 1024) : 0 // MB
      },
      storage: {
        status: 'available', // S3는 별도 헬스체크 필요
        usage: 34 // 목업 데이터
      }
    };

    res.status(200).json(healthData);
  } catch (error) {
    console.error('Health check error:', error);
    res.status(503).json({
      service: 'Main Service',
      status: 'unhealthy',
      timestamp: new Date().toISOString(),
      error: error.message
    });
  }
});

// 개별 서비스 헬스체크 함수
async function checkServiceHealth(serviceUrl) {
  const startTime = Date.now();
  
  try {
    const response = await axios.get(`${serviceUrl}/health`, {
      timeout: 5000,
      headers: {
        'User-Agent': 'Main-Service-HealthCheck/1.0'
      }
    });
    
    return {
      status: response.status === 200 ? 'healthy' : 'unhealthy',
      responseTime: Date.now() - startTime
    };
  } catch (error) {
    console.error(`Health check failed for ${serviceUrl}:`, error.message);
    return {
      status: 'unhealthy',
      responseTime: Date.now() - startTime,
      error: error.message
    };
  }
}

// Kubernetes liveness probe
router.get('/live', (req, res) => {
  res.status(200).send('OK');
});

// Kubernetes readiness probe
router.get('/ready', async (req, res) => {
  try {
    // Redis 연결 확인
    const redisHealth = await checkRedisHealth();
    
    if (redisHealth.status === 'connected') {
      res.status(200).send('Ready');
    } else {
      res.status(503).send('Not Ready - Redis unavailable');
    }
  } catch (error) {
    res.status(503).send('Not Ready - Health check failed');
  }
});

// 메트릭 엔드포인트 (Prometheus 형식)
router.get('/metrics', async (req, res) => {
  try {
    const redisStats = await cacheHelpers.getStats();
    const memoryUsage = process.memoryUsage();
    
    const metrics = `
# HELP main_service_uptime_seconds Total uptime of the service in seconds
# TYPE main_service_uptime_seconds counter
main_service_uptime_seconds ${process.uptime()}

# HELP main_service_memory_usage_bytes Memory usage in bytes
# TYPE main_service_memory_usage_bytes gauge
main_service_memory_usage_bytes{type="rss"} ${memoryUsage.rss}
main_service_memory_usage_bytes{type="heapTotal"} ${memoryUsage.heapTotal}
main_service_memory_usage_bytes{type="heapUsed"} ${memoryUsage.heapUsed}

# HELP redis_keyspace_hits_total Total number of successful lookups of keys
# TYPE redis_keyspace_hits_total counter
redis_keyspace_hits_total ${redisStats ? redisStats.keyspace_hits : 0}

# HELP redis_keyspace_misses_total Total number of failed lookups of keys
# TYPE redis_keyspace_misses_total counter
redis_keyspace_misses_total ${redisStats ? redisStats.keyspace_misses : 0}

# HELP redis_connected_clients Number of client connections
# TYPE redis_connected_clients gauge
redis_connected_clients ${redisStats ? redisStats.connected_clients : 0}
    `.trim();

    res.set('Content-Type', 'text/plain');
    res.send(metrics);
  } catch (error) {
    console.error('Metrics error:', error);
    res.status(500).send('Error generating metrics');
  }
});

module.exports = router;