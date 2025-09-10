const express = require('express');
const axios = require('axios');
const { cacheHelpers } = require('../config/redis');
const { withCircuitBreaker } = require('../middleware/circuitBreaker');

const router = express.Router();
const CATALOG_SERVICE_URL = process.env.CATALOG_SERVICE_URL || 'http://catalog-service:8000';

// 상품 목록 조회 (캐싱 적용)
router.get('/products', async (req, res) => {
  try {
    const { category, search, page = 1, limit = 20 } = req.query;
    const cacheKey = `products:${category || 'all'}:${search || ''}:${page}:${limit}`;
    
    // 캐시에서 먼저 확인
    const cachedData = await cacheHelpers.get(cacheKey);
    if (cachedData) {
      console.log('Cache hit for products');
      return res.json({
        ...cachedData,
        cached: true,
        timestamp: new Date().toISOString()
      });
    }

    // 캐시 미스 시 Catalog Service 호출
    const catalogResponse = await withCircuitBreaker(
      'catalog-service',
      () => axios.get(`${CATALOG_SERVICE_URL}/products`, {
        params: { category, search, page, limit },
        timeout: 10000
      })
    );

    const responseData = {
      products: catalogResponse.data,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: catalogResponse.data.length
      }
    };

    // 결과를 캐시에 저장 (5분 TTL)
    await cacheHelpers.set(cacheKey, responseData, 300);
    
    res.json({
      ...responseData,
      cached: false,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Catalog products error:', error);
    
    // Circuit Breaker가 열린 경우 또는 서비스 오류 시 목업 데이터 반환
    if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      const mockProducts = getMockProducts();
      res.json({
        products: mockProducts,
        pagination: { page: 1, limit: 20, total: mockProducts.length },
        cached: false,
        fallback: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to fetch products',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 특정 상품 조회
router.get('/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const cacheKey = `product:${id}`;
    
    // 캐시에서 먼저 확인
    const cachedData = await cacheHelpers.get(cacheKey);
    if (cachedData) {
      console.log(`Cache hit for product ${id}`);
      return res.json({
        ...cachedData,
        cached: true,
        timestamp: new Date().toISOString()
      });
    }

    // Catalog Service 호출
    const catalogResponse = await withCircuitBreaker(
      'catalog-service',
      () => axios.get(`${CATALOG_SERVICE_URL}/products/${id}`, {
        timeout: 10000
      })
    );

    // 결과를 캐시에 저장 (10분 TTL)
    await cacheHelpers.set(cacheKey, catalogResponse.data, 600);
    
    res.json({
      ...catalogResponse.data,
      cached: false,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error(`Catalog product ${req.params.id} error:`, error);
    
    if (error.response && error.response.status === 404) {
      res.status(404).json({
        error: 'Product not found',
        productId: req.params.id,
        timestamp: new Date().toISOString()
      });
    } else if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      // Fallback 데이터
      const mockProduct = getMockProducts().find(p => p.id === req.params.id);
      if (mockProduct) {
        res.json({
          ...mockProduct,
          fallback: true,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(404).json({
          error: 'Product not found',
          productId: req.params.id,
          fallback: true,
          timestamp: new Date().toISOString()
        });
      }
    } else {
      res.status(500).json({
        error: 'Failed to fetch product',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 카테고리 목록 조회
router.get('/categories', async (req, res) => {
  try {
    const cacheKey = 'categories:all';
    
    // 캐시에서 먼저 확인
    const cachedData = await cacheHelpers.get(cacheKey);
    if (cachedData) {
      console.log('Cache hit for categories');
      return res.json({
        categories: cachedData,
        cached: true,
        timestamp: new Date().toISOString()
      });
    }

    // Catalog Service 호출
    const catalogResponse = await withCircuitBreaker(
      'catalog-service',
      () => axios.get(`${CATALOG_SERVICE_URL}/categories`, {
        timeout: 10000
      })
    );

    // 결과를 캐시에 저장 (30분 TTL - 카테고리는 자주 변경되지 않음)
    await cacheHelpers.set(cacheKey, catalogResponse.data, 1800);
    
    res.json({
      categories: catalogResponse.data,
      cached: false,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Catalog categories error:', error);
    
    if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      const mockCategories = getMockCategories();
      res.json({
        categories: mockCategories,
        fallback: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to fetch categories',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 캐시 무효화 (관리자용)
router.delete('/cache', async (req, res) => {
  try {
    const { pattern = 'products:*' } = req.query;
    const keys = await cacheHelpers.keys(pattern);
    
    if (keys.length > 0) {
      await Promise.all(keys.map(key => cacheHelpers.del(key)));
    }
    
    res.json({
      message: 'Cache cleared successfully',
      clearedKeys: keys.length,
      pattern,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Cache clear error:', error);
    res.status(500).json({
      error: 'Failed to clear cache',
      message: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// 목업 데이터 함수들
function getMockProducts() {
  return [
    {
      id: '1',
      name: '노트북',
      description: '고성능 개발용 노트북',
      price: 1500000,
      category: 'electronics',
      stock: 15,
      imageUrl: null,
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z'
    },
    {
      id: '2',
      name: '무선 마우스',
      description: '인체공학적 무선 마우스',
      price: 50000,
      category: 'electronics',
      stock: 25,
      imageUrl: null,
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z'
    },
    {
      id: '3',
      name: 'JavaScript 완벽 가이드',
      description: '모던 JavaScript 개발을 위한 완벽한 가이드북',
      price: 45000,
      category: 'books',
      stock: 30,
      imageUrl: null,
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z'
    }
  ];
}

function getMockCategories() {
  return [
    {
      id: 'electronics',
      name: '전자제품',
      description: '컴퓨터 및 전자기기'
    },
    {
      id: 'books',
      name: '도서',
      description: '기술서적 및 일반도서'
    },
    {
      id: 'office',
      name: '사무용품',
      description: '사무실에서 사용하는 각종 용품'
    }
  ];
}

module.exports = router;