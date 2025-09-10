const express = require('express');
const axios = require('axios');
const { cacheHelpers } = require('../config/redis');
const { withCircuitBreaker } = require('../middleware/circuitBreaker');

const router = express.Router();
const ORDER_SERVICE_URL = process.env.ORDER_SERVICE_URL || 'http://order-service:8080';

// 주문 목록 조회
router.get('/', async (req, res) => {
  try {
    const { status, customerId, page = 1, limit = 20 } = req.query;
    const cacheKey = `orders:${status || 'all'}:${customerId || 'all'}:${page}:${limit}`;
    
    // 캐시에서 먼저 확인 (주문 데이터는 짧은 TTL 사용)
    const cachedData = await cacheHelpers.get(cacheKey);
    if (cachedData) {
      console.log('Cache hit for orders');
      return res.json({
        ...cachedData,
        cached: true,
        timestamp: new Date().toISOString()
      });
    }

    // Order Service 호출
    const orderResponse = await withCircuitBreaker(
      'order-service',
      () => axios.get(`${ORDER_SERVICE_URL}/api/orders`, {
        params: { status, customerId, page, limit },
        timeout: 10000
      })
    );

    const responseData = {
      orders: orderResponse.data,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: orderResponse.data.length
      }
    };

    // 결과를 캐시에 저장 (2분 TTL - 주문 데이터는 자주 변경됨)
    await cacheHelpers.set(cacheKey, responseData, 120);
    
    res.json({
      ...responseData,
      cached: false,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Orders list error:', error);
    
    if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      const mockOrders = getMockOrders();
      res.json({
        orders: mockOrders,
        pagination: { page: 1, limit: 20, total: mockOrders.length },
        fallback: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to fetch orders',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 특정 주문 조회
router.get('/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const cacheKey = `order:${id}`;
    
    // 캐시에서 먼저 확인
    const cachedData = await cacheHelpers.get(cacheKey);
    if (cachedData) {
      console.log(`Cache hit for order ${id}`);
      return res.json({
        ...cachedData,
        cached: true,
        timestamp: new Date().toISOString()
      });
    }

    // Order Service 호출
    const orderResponse = await withCircuitBreaker(
      'order-service',
      () => axios.get(`${ORDER_SERVICE_URL}/api/orders/${id}`, {
        timeout: 10000
      })
    );

    // 결과를 캐시에 저장 (5분 TTL)
    await cacheHelpers.set(cacheKey, orderResponse.data, 300);
    
    res.json({
      ...orderResponse.data,
      cached: false,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error(`Order ${req.params.id} error:`, error);
    
    if (error.response && error.response.status === 404) {
      res.status(404).json({
        error: 'Order not found',
        orderId: req.params.id,
        timestamp: new Date().toISOString()
      });
    } else if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      const mockOrder = getMockOrders().find(o => o.id === req.params.id);
      if (mockOrder) {
        res.json({
          ...mockOrder,
          fallback: true,
          timestamp: new Date().toISOString()
        });
      } else {
        res.status(404).json({
          error: 'Order not found',
          orderId: req.params.id,
          fallback: true,
          timestamp: new Date().toISOString()
        });
      }
    } else {
      res.status(500).json({
        error: 'Failed to fetch order',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 새 주문 생성
router.post('/', async (req, res) => {
  try {
    const orderData = req.body;
    
    // 입력 데이터 검증
    if (!orderData.customerId || !orderData.customerName || !orderData.items || orderData.items.length === 0) {
      return res.status(400).json({
        error: 'Invalid order data',
        message: 'customerId, customerName, and items are required',
        timestamp: new Date().toISOString()
      });
    }

    // Order Service 호출
    const orderResponse = await withCircuitBreaker(
      'order-service',
      () => axios.post(`${ORDER_SERVICE_URL}/api/orders`, orderData, {
        timeout: 15000,
        headers: {
          'Content-Type': 'application/json'
        }
      })
    );

    // 관련 캐시 무효화
    const cacheKeys = await cacheHelpers.keys('orders:*');
    if (cacheKeys.length > 0) {
      await Promise.all(cacheKeys.map(key => cacheHelpers.del(key)));
    }

    res.status(201).json({
      ...orderResponse.data,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Order creation error:', error);
    
    if (error.response && error.response.status === 400) {
      res.status(400).json({
        error: 'Invalid order data',
        message: error.response.data.message || error.message,
        timestamp: new Date().toISOString()
      });
    } else if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      // Fallback: 목업 주문 생성
      const mockOrder = createMockOrder(req.body);
      res.status(201).json({
        ...mockOrder,
        fallback: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to create order',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 주문 상태 변경
router.patch('/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status) {
      return res.status(400).json({
        error: 'Status is required',
        timestamp: new Date().toISOString()
      });
    }

    // Order Service 호출
    const orderResponse = await withCircuitBreaker(
      'order-service',
      () => axios.patch(`${ORDER_SERVICE_URL}/api/orders/${id}/status`, { status }, {
        timeout: 10000,
        headers: {
          'Content-Type': 'application/json'
        }
      })
    );

    // 관련 캐시 무효화
    await cacheHelpers.del(`order:${id}`);
    const cacheKeys = await cacheHelpers.keys('orders:*');
    if (cacheKeys.length > 0) {
      await Promise.all(cacheKeys.map(key => cacheHelpers.del(key)));
    }

    res.json({
      ...orderResponse.data,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error(`Order status update error for ${req.params.id}:`, error);
    
    if (error.response && error.response.status === 404) {
      res.status(404).json({
        error: 'Order not found',
        orderId: req.params.id,
        timestamp: new Date().toISOString()
      });
    } else if (error.response && error.response.status === 400) {
      res.status(400).json({
        error: 'Invalid status',
        message: error.response.data.message || error.message,
        timestamp: new Date().toISOString()
      });
    } else if (error.message.includes('Circuit breaker') || error.code === 'ECONNREFUSED') {
      res.status(503).json({
        error: 'Order service unavailable',
        message: 'Please try again later',
        fallback: true,
        timestamp: new Date().toISOString()
      });
    } else {
      res.status(500).json({
        error: 'Failed to update order status',
        message: error.message,
        timestamp: new Date().toISOString()
      });
    }
  }
});

// 목업 데이터 함수들
function getMockOrders() {
  return [
    {
      id: 'order-1',
      customerId: 'customer-1',
      customerName: '김개발',
      items: [
        {
          productId: '1',
          productName: '노트북',
          quantity: 1,
          price: 1500000
        }
      ],
      totalAmount: 1500000,
      status: 'confirmed',
      createdAt: '2024-01-01T10:00:00Z',
      updatedAt: '2024-01-01T10:30:00Z'
    },
    {
      id: 'order-2',
      customerId: 'customer-2',
      customerName: '이프론트',
      items: [
        {
          productId: '2',
          productName: '무선 마우스',
          quantity: 2,
          price: 50000
        },
        {
          productId: '3',
          productName: 'JavaScript 완벽 가이드',
          quantity: 1,
          price: 45000
        }
      ],
      totalAmount: 145000,
      status: 'processing',
      createdAt: '2024-01-02T14:30:00Z',
      updatedAt: '2024-01-02T15:00:00Z'
    }
  ];
}

function createMockOrder(orderData) {
  return {
    id: `order-${Date.now()}`,
    customerId: orderData.customerId,
    customerName: orderData.customerName,
    items: orderData.items.map(item => ({
      ...item,
      productName: `Product ${item.productId}`,
      price: 50000 // 목업 가격
    })),
    totalAmount: orderData.items.reduce((sum, item) => sum + (item.quantity * 50000), 0),
    status: 'pending',
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString()
  };
}

module.exports = router;