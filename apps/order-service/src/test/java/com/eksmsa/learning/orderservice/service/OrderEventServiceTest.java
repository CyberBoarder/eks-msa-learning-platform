package com.eksmsa.learning.orderservice.service;

import com.eksmsa.learning.orderservice.entity.OrderStatus;
import com.eksmsa.learning.orderservice.event.OrderEvent;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.RedisTemplate;

import java.math.BigDecimal;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderEventServiceTest {

    @Mock
    private RedisTemplate<String, Object> redisTemplate;

    @InjectMocks
    private OrderEventService orderEventService;

    @BeforeEach
    void setUp() {
        // RedisTemplate 모킹 설정
        doNothing().when(redisTemplate).convertAndSend(anyString(), anyString());
    }

    @Test
    void 주문_생성_이벤트_발행() {
        // Given
        String orderId = "ORD-001";
        String customerId = "CUST-001";
        String customerName = "홍길동";
        BigDecimal totalAmount = new BigDecimal("20000");
        String currency = "KRW";

        // When
        orderEventService.publishOrderCreatedEvent(orderId, customerId, customerName, totalAmount, currency);

        // Then
        verify(redisTemplate, times(3)).convertAndSend(anyString(), anyString());
        // order.events, order.notifications, order.analytics 채널에 각각 발행
    }

    @Test
    void 주문_상태_변경_이벤트_발행() {
        // Given
        String orderId = "ORD-001";
        String customerId = "CUST-001";
        OrderStatus previousStatus = OrderStatus.PENDING;
        OrderStatus newStatus = OrderStatus.CONFIRMED;
        String reason = "주문 확인";
        String changedBy = "ADMIN";

        // When
        orderEventService.publishOrderStatusChangedEvent(
            orderId, customerId, previousStatus, newStatus, reason, changedBy);

        // Then
        verify(redisTemplate, times(3)).convertAndSend(anyString(), anyString());
    }

    @Test
    void 주문_취소_이벤트_발행() {
        // Given
        String orderId = "ORD-001";
        String customerId = "CUST-001";
        String reason = "고객 요청";
        String cancelledBy = "CUSTOMER";

        // When
        orderEventService.publishOrderCancelledEvent(orderId, customerId, reason, cancelledBy);

        // Then
        verify(redisTemplate, times(3)).convertAndSend(anyString(), anyString());
    }

    @Test
    void 주문_배송_시작_이벤트_발행() {
        // Given
        String orderId = "ORD-001";
        String customerId = "CUST-001";
        String trackingNumber = "TRACK-123";

        // When
        orderEventService.publishOrderShippedEvent(orderId, customerId, trackingNumber);

        // Then
        verify(redisTemplate, times(3)).convertAndSend(anyString(), anyString());
    }

    @Test
    void 주문_배송_완료_이벤트_발행() {
        // Given
        String orderId = "ORD-001";
        String customerId = "CUST-001";

        // When
        orderEventService.publishOrderDeliveredEvent(orderId, customerId);

        // Then
        verify(redisTemplate, times(3)).convertAndSend(anyString(), anyString());
    }

    @Test
    void 이벤트_객체_생성_테스트() {
        // Given & When
        OrderEvent event = OrderEvent.orderCreated(
            "ORD-001", "CUST-001", "홍길동", 
            new BigDecimal("20000"), "KRW");

        // Then
        assertNotNull(event);
        assertEquals(OrderEvent.ORDER_CREATED, event.getEventType());
        assertEquals("ORD-001", event.getOrderId());
        assertEquals("CUST-001", event.getCustomerId());
        assertEquals("홍길동", event.getCustomerName());
        assertEquals(OrderStatus.PENDING, event.getOrderStatus());
        assertEquals(new BigDecimal("20000"), event.getTotalAmount());
        assertEquals("KRW", event.getCurrency());
        assertNotNull(event.getEventId());
        assertNotNull(event.getTimestamp());
    }

    @Test
    void 상태_변경_이벤트_객체_생성_테스트() {
        // Given & When
        OrderEvent event = OrderEvent.orderStatusChanged(
            "ORD-001", "CUST-001", 
            OrderStatus.PENDING, OrderStatus.CONFIRMED,
            "주문 확인", "ADMIN");

        // Then
        assertNotNull(event);
        assertEquals(OrderEvent.ORDER_STATUS_CHANGED, event.getEventType());
        assertEquals("ORD-001", event.getOrderId());
        assertEquals("CUST-001", event.getCustomerId());
        assertEquals(OrderStatus.PENDING, event.getPreviousStatus());
        assertEquals(OrderStatus.CONFIRMED, event.getOrderStatus());
        assertEquals("주문 확인", event.getReason());
        assertEquals("ADMIN", event.getChangedBy());
    }
}