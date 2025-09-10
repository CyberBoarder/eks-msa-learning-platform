const request = require('supertest');
const app = require('../index');

describe('Catalog API', () => {
  describe('GET /api/catalog/products', () => {
    it('should return products list', async () => {
      const response = await request(app)
        .get('/api/catalog/products')
        .expect(200);

      expect(response.body).toHaveProperty('products');
      expect(response.body).toHaveProperty('pagination');
      expect(response.body).toHaveProperty('timestamp');
      expect(Array.isArray(response.body.products)).toBe(true);
    });

    it('should support pagination', async () => {
      const response = await request(app)
        .get('/api/catalog/products?page=1&limit=10')
        .expect(200);

      expect(response.body.pagination).toHaveProperty('page', 1);
      expect(response.body.pagination).toHaveProperty('limit', 10);
    });

    it('should support category filtering', async () => {
      const response = await request(app)
        .get('/api/catalog/products?category=electronics')
        .expect(200);

      expect(response.body).toHaveProperty('products');
    });

    it('should support search', async () => {
      const response = await request(app)
        .get('/api/catalog/products?search=laptop')
        .expect(200);

      expect(response.body).toHaveProperty('products');
    });
  });

  describe('GET /api/catalog/products/:id', () => {
    it('should return a specific product', async () => {
      const response = await request(app)
        .get('/api/catalog/products/1')
        .expect(200);

      expect(response.body).toHaveProperty('id');
      expect(response.body).toHaveProperty('name');
      expect(response.body).toHaveProperty('price');
    });

    it('should return 404 for non-existent product', async () => {
      const response = await request(app)
        .get('/api/catalog/products/999999')
        .expect(404);

      expect(response.body).toHaveProperty('error', 'Product not found');
    });
  });

  describe('GET /api/catalog/categories', () => {
    it('should return categories list', async () => {
      const response = await request(app)
        .get('/api/catalog/categories')
        .expect(200);

      expect(response.body).toHaveProperty('categories');
      expect(response.body).toHaveProperty('timestamp');
      expect(Array.isArray(response.body.categories)).toBe(true);
    });
  });

  describe('DELETE /api/catalog/cache', () => {
    it('should clear cache successfully', async () => {
      const response = await request(app)
        .delete('/api/catalog/cache')
        .expect(200);

      expect(response.body).toHaveProperty('message', 'Cache cleared successfully');
      expect(response.body).toHaveProperty('clearedKeys');
    });

    it('should support pattern-based cache clearing', async () => {
      const response = await request(app)
        .delete('/api/catalog/cache?pattern=products:electronics:*')
        .expect(200);

      expect(response.body).toHaveProperty('pattern', 'products:electronics:*');
    });
  });
});