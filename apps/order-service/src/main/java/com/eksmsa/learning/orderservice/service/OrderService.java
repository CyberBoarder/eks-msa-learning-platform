package com.eksmsa.learning.orderservice.service;

import com.eksmsa.learning.orderservice.dto.*;
import com.eksmsa.learning.orderservice.entity.Order;
import com.eksmsa.learning.orderservice.entity.OrderItem;
import com.eksmsa.learning.orderservice.entity.OrderStatus;
import com.eksmsa.learning.orderservice.entity.OrderStatusHistory;
import com.eksmsa.learning.orderservice.repository.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
@Transactional
public class OrderService {

    private static final Logger logger = LoggerFactory.getLogger(OrderService.class);

    private final OrderRepository orderRepository;
    private final OrderItemService orderItemService;
    private final OrderEventService orderEventService;

    @Autowired
    public OrderService(OrderRepository orderRepository, OrderItemService orderItemService, 
                       OrderEventService orderEventService) {
        this.orderRepository = orderRepository;
        this.orderItemService = orderItemService;
        this.orderEventService = orderEventService;
    }

    /**
     * 새 주문 생성
     */
    public OrderResponse createOrder(OrderCreateRequest request) {
        logger.info("새 주문 생성 시작 - 고객: {}", request.getCustomerId());

        try {
            // 주문 ID 생성
            String orderId = generateOrderId();

            // 주문 엔티티 생성
            Order order = new Order(orderId, request.getCustomerId(), request.getCustomerName());
            order.setCustomerEmail(request.getCustomerEmail());
            order.setCustomerPhone(request.getCustomerPhone());
            order.setCurrency(request.getCurrency());
            order.setPaymentMethod(request.getPaymentMethod());
            order.setShippingAddress(request.getShippingAddress());
            order.setBillingAddress(request.getBillingAddress());
            order.setNotes(request.getNotes());

            // 할인, 세금, 배송비 설정
            if (request.getDiscountAmount() != null) {
                order.setDiscountAmount(request.getDiscountAmount());
            }
            if (request.getTaxAmount() != null) {
                order.setTaxAmount(request.getTaxAmount());
            }
            if (request.getShippingAmount() != null) {
                order.setShippingAmount(request.getShippingAmount());
            }

            // 주문 상품 추가
            for (OrderItemRequest itemRequest : request.getItems()) {
                OrderItem item = orderItemService.createOrderItem(itemRequest);
                order.addItem(item);
            }

            // 주문 저장
            Order savedOrder = orderRepository.save(order);

            // 주문 생성 이벤트 발행
            orderEventService.publishOrderCreatedEvent(
                savedOrder.getId(),
                savedOrder.getCustomerId(),
                savedOrder.getCustomerName(),
                savedOrder.getFinalAmount(),
                savedOrder.getCurrency()
            );

            logger.info("주문 생성 완료 - 주문 ID: {}, 총 금액: {}", savedOrder.getId(), savedOrder.getFinalAmount());

            return convertToResponse(savedOrder);

        } catch (Exception e) {
            logger.error("주문 생성 실패 - 고객: {}, 오류: {}", request.getCustomerId(), e.getMessage(), e);
            throw new RuntimeException("주문 생성에 실패했습니다: " + e.getMessage(), e);
        }
    }

    /**
     * 주문 조회 (ID로)
     */
    @Transactional(readOnly = true)
    public OrderResponse getOrder(String orderId) {
        logger.debug("주문 조회 - ID: {}", orderId);

        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new RuntimeException("주문을 찾을 수 없습니다: " + orderId));

        return convertToResponse(order);
    }

    /**
     * 고객별 주문 목록 조회
     */
    @Transactional(readOnly = true)
    public Page<OrderResponse> getOrdersByCustomer(String customerId, Pageable pageable) {
        logger.debug("고객별 주문 목록 조회 - 고객 ID: {}", customerId);

        Page<Order> orders = orderRepository.findByCustomerId(customerId, pageable);
        return orders.map(this::convertToResponse);
    }

    /**
     * 상태별 주문 목록 조회
     */
    @Transactional(readOnly = true)
    public Page<OrderResponse> getOrdersByStatus(OrderStatus status, Pageable pageable) {
        logger.debug("상태별 주문 목록 조회 - 상태: {}", status);

        Page<Order> orders = orderRepository.findByStatus(status, pageable);
        return orders.map(this::convertToResponse);
    }

    /**
     * 모든 주문 목록 조회
     */
    @Transactional(readOnly = true)
    public Page<OrderResponse> getAllOrders(Pageable pageable) {
        logger.debug("전체 주문 목록 조회");

        Page<Order> orders = orderRepository.findAll(pageable);
        return orders.map(this::convertToResponse);
    }

    /**
     * 주문 상태 변경
     */
    public OrderResponse updateOrderStatus(String orderId, OrderStatusUpdateRequest request) {
        logger.info("주문 상태 변경 시작 - 주문 ID: {}, 새 상태: {}", orderId, request.getStatus());

        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new RuntimeException("주문을 찾을 수 없습니다: " + orderId));

        // 상태 변경 가능 여부 확인
        if (!order.getStatus().canTransitionTo(request.getStatus())) {
            throw new RuntimeException(
                String.format("주문 상태를 %s에서 %s로 변경할 수 없습니다", 
                    order.getStatus().getDescription(), 
                    request.getStatus().getDescription())
            );
        }

        // 이전 상태 저장
        OrderStatus previousStatus = order.getStatus();

        // 상태 변경
        order.updateStatus(request.getStatus());

        // 배송 추적 번호 설정
        if (request.getTrackingNumber() != null && !request.getTrackingNumber().trim().isEmpty()) {
            order.setTrackingNumber(request.getTrackingNumber());
        }

        // 상태 히스토리에 추가 정보 설정
        if (!order.getStatusHistory().isEmpty()) {
            OrderStatusHistory latestHistory = order.getStatusHistory().get(order.getStatusHistory().size() - 1);
            latestHistory.setReason(request.getReason());
            latestHistory.setChangedBy(request.getChangedBy());
        }

        Order savedOrder = orderRepository.save(order);

        // 상태 변경 이벤트 발행
        if (request.getStatus() == OrderStatus.SHIPPED) {
            orderEventService.publishOrderShippedEvent(
                savedOrder.getId(),
                savedOrder.getCustomerId(),
                savedOrder.getTrackingNumber()
            );
        } else if (request.getStatus() == OrderStatus.DELIVERED) {
            orderEventService.publishOrderDeliveredEvent(
                savedOrder.getId(),
                savedOrder.getCustomerId()
            );
        } else {
            orderEventService.publishOrderStatusChangedEvent(
                savedOrder.getId(),
                savedOrder.getCustomerId(),
                previousStatus,
                request.getStatus(),
                request.getReason(),
                request.getChangedBy()
            );
        }

        logger.info("주문 상태 변경 완료 - 주문 ID: {}, 상태: {}", orderId, request.getStatus());

        return convertToResponse(savedOrder);
    }

    /**
     * 주문 취소
     */
    public OrderResponse cancelOrder(String orderId, String reason, String cancelledBy) {
        logger.info("주문 취소 시작 - 주문 ID: {}", orderId);

        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new RuntimeException("주문을 찾을 수 없습니다: " + orderId));

        if (!order.canBeCancelled()) {
            throw new RuntimeException("현재 상태에서는 주문을 취소할 수 없습니다: " + order.getStatus().getDescription());
        }

        OrderStatusUpdateRequest cancelRequest = new OrderStatusUpdateRequest();
        cancelRequest.setStatus(OrderStatus.CANCELLED);
        cancelRequest.setReason(reason);
        cancelRequest.setChangedBy(cancelledBy);

        OrderResponse result = updateOrderStatus(orderId, cancelRequest);

        // 주문 취소 이벤트 발행
        orderEventService.publishOrderCancelledEvent(orderId, order.getCustomerId(), reason, cancelledBy);

        return result;
    }

    /**
     * 배송 추적 번호로 주문 조회
     */
    @Transactional(readOnly = true)
    public OrderResponse getOrderByTrackingNumber(String trackingNumber) {
        logger.debug("배송 추적 번호로 주문 조회 - 추적 번호: {}", trackingNumber);

        Order order = orderRepository.findByTrackingNumber(trackingNumber)
            .orElseThrow(() -> new RuntimeException("해당 추적 번호의 주문을 찾을 수 없습니다: " + trackingNumber));

        return convertToResponse(order);
    }

    /**
     * 주문 통계 조회
     */
    @Transactional(readOnly = true)
    public List<Object[]> getOrderStatistics() {
        logger.debug("주문 통계 조회");
        return orderRepository.getOrderStatusStatistics();
    }

    /**
     * 기간별 매출 조회
     */
    @Transactional(readOnly = true)
    public Double getRevenueBetween(LocalDateTime startDate, LocalDateTime endDate) {
        logger.debug("기간별 매출 조회 - 시작: {}, 종료: {}", startDate, endDate);
        return orderRepository.getTotalRevenueBetween(startDate, endDate);
    }

    /**
     * 주문 ID 생성
     */
    private String generateOrderId() {
        return "ORD-" + System.currentTimeMillis() + "-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    /**
     * Order 엔티티를 OrderResponse DTO로 변환
     */
    private OrderResponse convertToResponse(Order order) {
        OrderResponse response = new OrderResponse();
        
        response.setId(order.getId());
        response.setCustomerId(order.getCustomerId());
        response.setCustomerName(order.getCustomerName());
        response.setCustomerEmail(order.getCustomerEmail());
        response.setCustomerPhone(order.getCustomerPhone());
        response.setStatus(order.getStatus());
        response.setTotalAmount(order.getTotalAmount());
        response.setDiscountAmount(order.getDiscountAmount());
        response.setTaxAmount(order.getTaxAmount());
        response.setShippingAmount(order.getShippingAmount());
        response.setFinalAmount(order.getFinalAmount());
        response.setCurrency(order.getCurrency());
        response.setPaymentMethod(order.getPaymentMethod());
        response.setPaymentStatus(order.getPaymentStatus());
        response.setShippingAddress(order.getShippingAddress());
        response.setBillingAddress(order.getBillingAddress());
        response.setNotes(order.getNotes());
        response.setTrackingNumber(order.getTrackingNumber());
        response.setEstimatedDeliveryDate(order.getEstimatedDeliveryDate());
        response.setDeliveredAt(order.getDeliveredAt());
        response.setCreatedAt(order.getCreatedAt());
        response.setUpdatedAt(order.getUpdatedAt());

        // 주문 상품 변환
        if (order.getItems() != null) {
            List<OrderItemResponse> itemResponses = order.getItems().stream()
                .map(this::convertItemToResponse)
                .collect(Collectors.toList());
            response.setItems(itemResponses);
        }

        // 상태 히스토리 변환
        if (order.getStatusHistory() != null) {
            List<OrderStatusHistoryResponse> historyResponses = order.getStatusHistory().stream()
                .map(this::convertHistoryToResponse)
                .collect(Collectors.toList());
            response.setStatusHistory(historyResponses);
        }

        return response;
    }

    /**
     * OrderItem 엔티티를 OrderItemResponse DTO로 변환
     */
    private OrderItemResponse convertItemToResponse(OrderItem item) {
        OrderItemResponse response = new OrderItemResponse();
        
        response.setId(item.getId());
        response.setProductId(item.getProductId());
        response.setProductName(item.getProductName());
        response.setProductSku(item.getProductSku());
        response.setProductImageUrl(item.getProductImageUrl());
        response.setUnitPrice(item.getUnitPrice());
        response.setQuantity(item.getQuantity());
        response.setSubtotal(item.getSubtotal());
        response.setDiscountAmount(item.getDiscountAmount());
        response.setTaxAmount(item.getTaxAmount());
        response.setFinalAmount(item.getFinalAmount());
        response.setNotes(item.getNotes());
        response.setCreatedAt(item.getCreatedAt());
        response.setUpdatedAt(item.getUpdatedAt());

        return response;
    }

    /**
     * OrderStatusHistory 엔티티를 OrderStatusHistoryResponse DTO로 변환
     */
    private OrderStatusHistoryResponse convertHistoryToResponse(OrderStatusHistory history) {
        OrderStatusHistoryResponse response = new OrderStatusHistoryResponse();
        
        response.setId(history.getId());
        response.setFromStatus(history.getFromStatus());
        response.setToStatus(history.getToStatus());
        response.setReason(history.getReason());
        response.setChangedBy(history.getChangedBy());
        response.setChangedAt(history.getChangedAt());

        return response;
    }
}