const redis = require('redis');

// Redis 클라이언트 설정
const redisClient = redis.createClient({
  host: process.env.REDIS_HOST || 'localhost',
  port: process.env.REDIS_PORT || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: process.env.REDIS_DB || 0,
  retry_strategy: (options) => {
    if (options.error && options.error.code === 'ECONNREFUSED') {
      console.error('Redis connection refused');
      return new Error('Redis connection refused');
    }
    if (options.total_retry_time > 1000 * 60 * 60) {
      console.error('Redis retry time exhausted');
      return new Error('Retry time exhausted');
    }
    if (options.attempt > 10) {
      console.error('Redis max retry attempts reached');
      return undefined;
    }
    // 재연결 시도 간격 (밀리초)
    return Math.min(options.attempt * 100, 3000);
  },
});

// Redis 연결 이벤트 핸들러
redisClient.on('connect', () => {
  console.log('Redis client connected');
});

redisClient.on('ready', () => {
  console.log('Redis client ready');
});

redisClient.on('error', (err) => {
  console.error('Redis client error:', err);
});

redisClient.on('end', () => {
  console.log('Redis client disconnected');
});

// Redis 헬스체크 함수
const checkRedisHealth = async () => {
  try {
    await redisClient.ping();
    return { status: 'connected', message: 'Redis is healthy' };
  } catch (error) {
    return { status: 'disconnected', message: error.message };
  }
};

// 캐시 헬퍼 함수들
const cacheHelpers = {
  // 캐시에서 데이터 가져오기
  async get(key) {
    try {
      const data = await redisClient.get(key);
      return data ? JSON.parse(data) : null;
    } catch (error) {
      console.error('Cache get error:', error);
      return null;
    }
  },

  // 캐시에 데이터 저장하기
  async set(key, data, ttl = 300) {
    try {
      await redisClient.setex(key, ttl, JSON.stringify(data));
      return true;
    } catch (error) {
      console.error('Cache set error:', error);
      return false;
    }
  },

  // 캐시에서 데이터 삭제하기
  async del(key) {
    try {
      await redisClient.del(key);
      return true;
    } catch (error) {
      console.error('Cache delete error:', error);
      return false;
    }
  },

  // 패턴으로 키 검색하기
  async keys(pattern) {
    try {
      return await redisClient.keys(pattern);
    } catch (error) {
      console.error('Cache keys error:', error);
      return [];
    }
  },

  // 캐시 통계 가져오기
  async getStats() {
    try {
      const info = await redisClient.info('stats');
      const lines = info.split('\r\n');
      const stats = {};
      
      lines.forEach(line => {
        if (line.includes(':')) {
          const [key, value] = line.split(':');
          stats[key] = value;
        }
      });

      return {
        keyspace_hits: parseInt(stats.keyspace_hits) || 0,
        keyspace_misses: parseInt(stats.keyspace_misses) || 0,
        connected_clients: parseInt(stats.connected_clients) || 0,
        used_memory: parseInt(stats.used_memory) || 0,
      };
    } catch (error) {
      console.error('Cache stats error:', error);
      return null;
    }
  }
};

module.exports = {
  redisClient,
  checkRedisHealth,
  cacheHelpers
};