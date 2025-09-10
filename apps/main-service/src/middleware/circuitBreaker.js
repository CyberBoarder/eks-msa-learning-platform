const CircuitBreaker = require('opossum');

// Circuit Breaker 인스턴스들을 저장할 Map
const circuitBreakers = new Map();

// Circuit Breaker 기본 옵션
const defaultOptions = {
  timeout: 10000, // 10초 타임아웃
  errorThresholdPercentage: 50, // 50% 실패율에서 Circuit Breaker 열림
  resetTimeout: 30000, // 30초 후 Half-Open 상태로 전환
  rollingCountTimeout: 10000, // 10초 동안의 통계 수집
  rollingCountBuckets: 10, // 통계를 10개 버킷으로 분할
  volumeThreshold: 10, // 최소 10개 요청 후 Circuit Breaker 동작
  capacity: 2, // Half-Open 상태에서 최대 2개 요청 허용
};

// Circuit Breaker 생성 또는 가져오기
function getCircuitBreaker(serviceName, options = {}) {
  if (!circuitBreakers.has(serviceName)) {
    const circuitBreakerOptions = { ...defaultOptions, ...options };
    
    // 더미 함수 (실제 함수는 withCircuitBreaker에서 전달됨)
    const circuitBreaker = new CircuitBreaker(() => Promise.resolve(), circuitBreakerOptions);
    
    // 이벤트 리스너 설정
    circuitBreaker.on('open', () => {
      console.log(`Circuit breaker opened for ${serviceName}`);
    });
    
    circuitBreaker.on('halfOpen', () => {
      console.log(`Circuit breaker half-opened for ${serviceName}`);
    });
    
    circuitBreaker.on('close', () => {
      console.log(`Circuit breaker closed for ${serviceName}`);
    });
    
    circuitBreaker.on('failure', (error) => {
      console.log(`Circuit breaker failure for ${serviceName}:`, error.message);
    });
    
    circuitBreaker.on('success', () => {
      console.log(`Circuit breaker success for ${serviceName}`);
    });
    
    circuitBreaker.on('timeout', () => {
      console.log(`Circuit breaker timeout for ${serviceName}`);
    });
    
    circuitBreaker.on('reject', () => {
      console.log(`Circuit breaker rejected request for ${serviceName}`);
    });
    
    circuitBreakers.set(serviceName, circuitBreaker);
  }
  
  return circuitBreakers.get(serviceName);
}

// Circuit Breaker와 함께 함수 실행
async function withCircuitBreaker(serviceName, fn, options = {}) {
  const circuitBreaker = getCircuitBreaker(serviceName, options);
  
  try {
    // Circuit Breaker를 통해 함수 실행
    const result = await circuitBreaker.fire(fn);
    return result;
  } catch (error) {
    // Circuit Breaker가 열린 상태에서 요청이 거부된 경우
    if (error.message === 'Breaker is open') {
      throw new Error(`Circuit breaker is open for ${serviceName}`);
    }
    
    // 타임아웃 에러
    if (error.code === 'ETIMEDOUT' || error.message.includes('timeout')) {
      throw new Error(`Request timeout for ${serviceName}`);
    }
    
    // 기타 에러는 그대로 전파
    throw error;
  }
}

// Circuit Breaker 상태 조회
function getCircuitBreakerStats(serviceName) {
  const circuitBreaker = circuitBreakers.get(serviceName);
  
  if (!circuitBreaker) {
    return null;
  }
  
  const stats = circuitBreaker.stats;
  
  return {
    serviceName,
    state: circuitBreaker.opened ? 'OPEN' : circuitBreaker.halfOpen ? 'HALF_OPEN' : 'CLOSED',
    requests: stats.requests,
    successes: stats.successes,
    failures: stats.failures,
    rejects: stats.rejects,
    timeouts: stats.timeouts,
    failureRate: stats.requests > 0 ? (stats.failures / stats.requests * 100).toFixed(2) : 0,
    averageResponseTime: stats.averageResponseTime || 0,
    lastFailureTime: stats.lastFailureTime,
    nextAttempt: circuitBreaker.opened ? new Date(Date.now() + circuitBreaker.options.resetTimeout) : null
  };
}

// 모든 Circuit Breaker 상태 조회
function getAllCircuitBreakerStats() {
  const allStats = {};
  
  for (const serviceName of circuitBreakers.keys()) {
    allStats[serviceName] = getCircuitBreakerStats(serviceName);
  }
  
  return allStats;
}

// Circuit Breaker 리셋 (관리자용)
function resetCircuitBreaker(serviceName) {
  const circuitBreaker = circuitBreakers.get(serviceName);
  
  if (circuitBreaker) {
    circuitBreaker.close();
    return true;
  }
  
  return false;
}

// Express 미들웨어
function circuitBreakerMiddleware(req, res, next) {
  // Circuit Breaker 상태를 요청 객체에 추가
  req.circuitBreaker = {
    withCircuitBreaker,
    getStats: getCircuitBreakerStats,
    getAllStats: getAllCircuitBreakerStats,
    reset: resetCircuitBreaker
  };
  
  next();
}

// Circuit Breaker 상태 엔드포인트용 라우터
const express = require('express');
const router = express.Router();

// 모든 Circuit Breaker 상태 조회
router.get('/circuit-breakers', (req, res) => {
  const stats = getAllCircuitBreakerStats();
  
  res.json({
    circuitBreakers: stats,
    timestamp: new Date().toISOString()
  });
});

// 특정 Circuit Breaker 상태 조회
router.get('/circuit-breakers/:serviceName', (req, res) => {
  const { serviceName } = req.params;
  const stats = getCircuitBreakerStats(serviceName);
  
  if (!stats) {
    return res.status(404).json({
      error: 'Circuit breaker not found',
      serviceName,
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    circuitBreaker: stats,
    timestamp: new Date().toISOString()
  });
});

// Circuit Breaker 리셋
router.post('/circuit-breakers/:serviceName/reset', (req, res) => {
  const { serviceName } = req.params;
  const success = resetCircuitBreaker(serviceName);
  
  if (!success) {
    return res.status(404).json({
      error: 'Circuit breaker not found',
      serviceName,
      timestamp: new Date().toISOString()
    });
  }
  
  res.json({
    message: `Circuit breaker reset successfully for ${serviceName}`,
    serviceName,
    timestamp: new Date().toISOString()
  });
});

module.exports = {
  circuitBreakerMiddleware,
  withCircuitBreaker,
  getCircuitBreakerStats,
  getAllCircuitBreakerStats,
  resetCircuitBreaker,
  circuitBreakerRouter: router
};