package com.eksmsa.learning.orderservice.service;

import com.eksmsa.learning.orderservice.dto.OrderCreateRequest;
import com.eksmsa.learning.orderservice.dto.OrderItemRequest;
import com.eksmsa.learning.orderservice.dto.OrderResponse;
import com.eksmsa.learning.orderservice.dto.OrderStatusUpdateRequest;
import com.eksmsa.learning.orderservice.entity.Order;
import com.eksmsa.learning.orderservice.entity.OrderStatus;
import com.eksmsa.learning.orderservice.repository.OrderRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;

import java.math.BigDecimal;
import java.util.Arrays;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class OrderServiceTest {

    @Mock
    private OrderRepository orderRepository;

    @Mock
    private OrderItemService orderItemService;

    @Mock
    private OrderEventService orderEventService;

    @InjectMocks
    private OrderService orderService;

    private OrderCreateRequest orderCreateRequest;
    private Order order;

    @BeforeEach
    void setUp() {
        // 주문 생성 요청 설정
        orderCreateRequest = new OrderCreateRequest();
        orderCreateRequest.setCustomerId("CUST-001");
        orderCreateRequest.setCustomerName("홍길동");
        orderCreateRequest.setCustomerEmail("hong@example.com");
        orderCreateRequest.setCustomerPhone("010-1234-5678");
        orderCreateRequest.setCurrency("KRW");
        orderCreateRequest.setPaymentMethod("CARD");
        orderCreateRequest.setShippingAddress("서울시 강남구");

        // 주문 상품 설정
        OrderItemRequest itemRequest = new OrderItemRequest();
        itemRequest.setProductId("PROD-001");
        itemRequest.setProductName("테스트 상품");
        itemRequest.setUnitPrice(new BigDecimal("10000"));
        itemRequest.setQuantity(2);
        orderCreateRequest.setItems(Arrays.asList(itemRequest));

        // 주문 엔티티 설정
        order = new Order("ORD-001", "CUST-001", "홍길동");
        order.setCustomerEmail("hong@example.com");
        order.setStatus(OrderStatus.PENDING);
        order.setTotalAmount(new BigDecimal("20000"));
        order.setFinalAmount(new BigDecimal("20000"));
    }

    @Test
    void 주문_생성_성공() {
        // Given
        when(orderRepository.save(any(Order.class))).thenReturn(order);
        doNothing().when(orderEventService).publishOrderCreatedEvent(
            anyString(), anyString(), anyString(), any(BigDecimal.class), anyString());

        // When
        OrderResponse result = orderService.createOrder(orderCreateRequest);

        // Then
        assertNotNull(result);
        assertEquals("CUST-001", result.getCustomerId());
        assertEquals("홍길동", result.getCustomerName());
        assertEquals(OrderStatus.PENDING, result.getStatus());
        
        verify(orderRepository, times(1)).save(any(Order.class));
        verify(orderEventService, times(1)).publishOrderCreatedEvent(
            anyString(), anyString(), anyString(), any(BigDecimal.class), anyString());
    }

    @Test
    void 주문_조회_성공() {
        // Given
        when(orderRepository.findById("ORD-001")).thenReturn(Optional.of(order));

        // When
        OrderResponse result = orderService.getOrder("ORD-001");

        // Then
        assertNotNull(result);
        assertEquals("ORD-001", result.getId());
        assertEquals("CUST-001", result.getCustomerId());
        
        verify(orderRepository, times(1)).findById("ORD-001");
    }

    @Test
    void 주문_조회_실패_존재하지_않는_주문() {
        // Given
        when(orderRepository.findById("INVALID-ID")).thenReturn(Optional.empty());

        // When & Then
        RuntimeException exception = assertThrows(RuntimeException.class, 
            () -> orderService.getOrder("INVALID-ID"));
        
        assertTrue(exception.getMessage().contains("주문을 찾을 수 없습니다"));
        verify(orderRepository, times(1)).findById("INVALID-ID");
    }

    @Test
    void 고객별_주문_목록_조회() {
        // Given
        Pageable pageable = PageRequest.of(0, 10);
        List<Order> orders = Arrays.asList(order);
        Page<Order> orderPage = new PageImpl<>(orders, pageable, 1);
        
        when(orderRepository.findByCustomerId("CUST-001", pageable)).thenReturn(orderPage);

        // When
        Page<OrderResponse> result = orderService.getOrdersByCustomer("CUST-001", pageable);

        // Then
        assertNotNull(result);
        assertEquals(1, result.getTotalElements());
        assertEquals("CUST-001", result.getContent().get(0).getCustomerId());
        
        verify(orderRepository, times(1)).findByCustomerId("CUST-001", pageable);
    }

    @Test
    void 주문_상태_변경_성공() {
        // Given
        OrderStatusUpdateRequest request = new OrderStatusUpdateRequest();
        request.setStatus(OrderStatus.CONFIRMED);
        request.setReason("주문 확인");
        request.setChangedBy("ADMIN");

        when(orderRepository.findById("ORD-001")).thenReturn(Optional.of(order));
        when(orderRepository.save(any(Order.class))).thenReturn(order);
        doNothing().when(orderEventService).publishOrderStatusChangedEvent(
            anyString(), anyString(), any(OrderStatus.class), any(OrderStatus.class), 
            anyString(), anyString());

        // When
        OrderResponse result = orderService.updateOrderStatus("ORD-001", request);

        // Then
        assertNotNull(result);
        verify(orderRepository, times(1)).findById("ORD-001");
        verify(orderRepository, times(1)).save(any(Order.class));
        verify(orderEventService, times(1)).publishOrderStatusChangedEvent(
            anyString(), anyString(), any(OrderStatus.class), any(OrderStatus.class), 
            anyString(), anyString());
    }

    @Test
    void 주문_취소_성공() {
        // Given
        when(orderRepository.findById("ORD-001")).thenReturn(Optional.of(order));
        when(orderRepository.save(any(Order.class))).thenReturn(order);
        doNothing().when(orderEventService).publishOrderStatusChangedEvent(
            anyString(), anyString(), any(OrderStatus.class), any(OrderStatus.class), 
            anyString(), anyString());
        doNothing().when(orderEventService).publishOrderCancelledEvent(
            anyString(), anyString(), anyString(), anyString());

        // When
        OrderResponse result = orderService.cancelOrder("ORD-001", "고객 요청", "CUSTOMER");

        // Then
        assertNotNull(result);
        verify(orderRepository, times(1)).findById("ORD-001");
        verify(orderEventService, times(1)).publishOrderCancelledEvent(
            anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void 주문_취소_실패_취소_불가능한_상태() {
        // Given
        order.setStatus(OrderStatus.DELIVERED); // 배송 완료 상태
        when(orderRepository.findById("ORD-001")).thenReturn(Optional.of(order));

        // When & Then
        RuntimeException exception = assertThrows(RuntimeException.class, 
            () -> orderService.cancelOrder("ORD-001", "고객 요청", "CUSTOMER"));
        
        assertTrue(exception.getMessage().contains("주문을 취소할 수 없습니다"));
        verify(orderRepository, times(1)).findById("ORD-001");
        verify(orderEventService, never()).publishOrderCancelledEvent(
            anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void 배송_추적_번호로_주문_조회() {
        // Given
        order.setTrackingNumber("TRACK-123");
        when(orderRepository.findByTrackingNumber("TRACK-123")).thenReturn(Optional.of(order));

        // When
        OrderResponse result = orderService.getOrderByTrackingNumber("TRACK-123");

        // Then
        assertNotNull(result);
        assertEquals("ORD-001", result.getId());
        assertEquals("TRACK-123", result.getTrackingNumber());
        
        verify(orderRepository, times(1)).findByTrackingNumber("TRACK-123");
    }
}