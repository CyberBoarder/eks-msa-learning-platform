const request = require('supertest');
const app = require('../index');

describe('Health Endpoints', () => {
  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('service', 'Main Service');
      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('memory');
    });
  });

  describe('GET /health/live', () => {
    it('should return OK for liveness probe', async () => {
      const response = await request(app)
        .get('/health/live')
        .expect(200);

      expect(response.text).toBe('OK');
    });
  });

  describe('GET /health/ready', () => {
    it('should return readiness status', async () => {
      const response = await request(app)
        .get('/health/ready')
        .expect(200);

      expect(response.text).toBe('Ready');
    });
  });

  describe('GET /health/metrics', () => {
    it('should return Prometheus metrics', async () => {
      const response = await request(app)
        .get('/health/metrics')
        .expect(200);

      expect(response.headers['content-type']).toBe('text/plain; charset=utf-8');
      expect(response.text).toContain('main_service_uptime_seconds');
      expect(response.text).toContain('main_service_memory_usage_bytes');
    });
  });

  describe('GET /health/detailed', () => {
    it('should return detailed health information', async () => {
      const response = await request(app)
        .get('/health/detailed')
        .expect(200);

      expect(response.body).toHaveProperty('service', 'Main Service');
      expect(response.body).toHaveProperty('services');
      expect(response.body).toHaveProperty('database');
      expect(response.body).toHaveProperty('cache');
      expect(response.body).toHaveProperty('storage');
      
      expect(Array.isArray(response.body.services)).toBe(true);
      expect(response.body.services.length).toBeGreaterThan(0);
    });
  });
});