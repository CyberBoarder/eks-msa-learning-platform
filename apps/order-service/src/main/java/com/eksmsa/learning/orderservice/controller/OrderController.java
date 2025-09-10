package com.eksmsa.learning.orderservice.controller;

import com.eksmsa.learning.orderservice.dto.*;
import com.eksmsa.learning.orderservice.entity.OrderStatus;
import com.eksmsa.learning.orderservice.service.OrderService;
import io.micrometer.core.annotation.Timed;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import jakarta.validation.Valid;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/orders")
@Validated
@CrossOrigin(origins = "*")
public class OrderController {

    private static final Logger logger = LoggerFactory.getLogger(OrderController.class);

    private final OrderService orderService;
    private final Counter orderCreatedCounter;
    private final Counter orderStatusUpdatedCounter;

    @Autowired
    public OrderController(OrderService orderService, MeterRegistry meterRegistry) {
        this.orderService = orderService;
        this.orderCreatedCounter = Counter.builder("orders.created")
            .description("Number of orders created")
            .register(meterRegistry);
        this.orderStatusUpdatedCounter = Counter.builder("orders.status.updated")
            .description("Number of order status updates")
            .register(meterRegistry);
    }

    /**
     * 새 주문 생성
     */
    @PostMapping
    @Timed(name = "orders.create", description = "Time taken to create an order")
    public ResponseEntity<Map<String, Object>> createOrder(@Valid @RequestBody OrderCreateRequest request) {
        logger.info("새 주문 생성 요청 - 고객: {}", request.getCustomerId());

        try {
            OrderResponse order = orderService.createOrder(request);
            orderCreatedCounter.increment();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "주문이 성공적으로 생성되었습니다");
            response.put("data", order);

            logger.info("주문 생성 성공 - 주문 ID: {}", order.getId());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);

        } catch (Exception e) {
            logger.error("주문 생성 실패 - 고객: {}, 오류: {}", request.getCustomerId(), e.getMessage(), e);
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "주문 생성에 실패했습니다: " + e.getMessage());
            errorResponse.put("error", e.getClass().getSimpleName());

            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 주문 상세 조회
     */
    @GetMapping("/{orderId}")
    @Timed(name = "orders.get", description = "Time taken to get an order")
    public ResponseEntity<Map<String, Object>> getOrder(@PathVariable String orderId) {
        logger.debug("주문 조회 요청 - 주문 ID: {}", orderId);

        try {
            OrderResponse order = orderService.getOrder(orderId);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("data", order);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("주문 조회 실패 - 주문 ID: {}, 오류: {}", orderId, e.getMessage());
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "주문을 찾을 수 없습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        }
    }

    /**
     * 주문 목록 조회 (페이징)
     */
    @GetMapping
    @Timed(name = "orders.list", description = "Time taken to list orders")
    public ResponseEntity<Map<String, Object>> getOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir,
            @RequestParam(required = false) String customerId,
            @RequestParam(required = false) OrderStatus status) {

        logger.debug("주문 목록 조회 - 페이지: {}, 크기: {}, 고객: {}, 상태: {}", page, size, customerId, status);

        try {
            Sort sort = sortDir.equalsIgnoreCase("desc") ? 
                Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
            Pageable pageable = PageRequest.of(page, size, sort);

            Page<OrderResponse> orders;
            
            if (customerId != null && status != null) {
                // 고객 및 상태별 조회는 별도 구현 필요
                orders = orderService.getOrdersByCustomer(customerId, pageable);
            } else if (customerId != null) {
                orders = orderService.getOrdersByCustomer(customerId, pageable);
            } else if (status != null) {
                orders = orderService.getOrdersByStatus(status, pageable);
            } else {
                orders = orderService.getAllOrders(pageable);
            }

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("data", orders.getContent());
            response.put("pagination", Map.of(
                "currentPage", orders.getNumber(),
                "totalPages", orders.getTotalPages(),
                "totalElements", orders.getTotalElements(),
                "size", orders.getSize(),
                "hasNext", orders.hasNext(),
                "hasPrevious", orders.hasPrevious()
            ));

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("주문 목록 조회 실패 - 오류: {}", e.getMessage(), e);
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "주문 목록 조회에 실패했습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 주문 상태 변경
     */
    @PutMapping("/{orderId}/status")
    @Timed(name = "orders.status.update", description = "Time taken to update order status")
    public ResponseEntity<Map<String, Object>> updateOrderStatus(
            @PathVariable String orderId,
            @Valid @RequestBody OrderStatusUpdateRequest request) {

        logger.info("주문 상태 변경 요청 - 주문 ID: {}, 새 상태: {}", orderId, request.getStatus());

        try {
            OrderResponse order = orderService.updateOrderStatus(orderId, request);
            orderStatusUpdatedCounter.increment();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "주문 상태가 성공적으로 변경되었습니다");
            response.put("data", order);

            logger.info("주문 상태 변경 성공 - 주문 ID: {}, 상태: {}", orderId, request.getStatus());
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("주문 상태 변경 실패 - 주문 ID: {}, 오류: {}", orderId, e.getMessage(), e);
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "주문 상태 변경에 실패했습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 주문 취소
     */
    @PutMapping("/{orderId}/cancel")
    @Timed(name = "orders.cancel", description = "Time taken to cancel an order")
    public ResponseEntity<Map<String, Object>> cancelOrder(
            @PathVariable String orderId,
            @RequestParam(required = false) String reason,
            @RequestParam(required = false) String cancelledBy) {

        logger.info("주문 취소 요청 - 주문 ID: {}", orderId);

        try {
            OrderResponse order = orderService.cancelOrder(orderId, reason, cancelledBy);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "주문이 성공적으로 취소되었습니다");
            response.put("data", order);

            logger.info("주문 취소 성공 - 주문 ID: {}", orderId);
            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("주문 취소 실패 - 주문 ID: {}, 오류: {}", orderId, e.getMessage(), e);
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "주문 취소에 실패했습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(errorResponse);
        }
    }

    /**
     * 배송 추적 번호로 주문 조회
     */
    @GetMapping("/tracking/{trackingNumber}")
    @Timed(name = "orders.tracking", description = "Time taken to track an order")
    public ResponseEntity<Map<String, Object>> trackOrder(@PathVariable String trackingNumber) {
        logger.debug("주문 추적 요청 - 추적 번호: {}", trackingNumber);

        try {
            OrderResponse order = orderService.getOrderByTrackingNumber(trackingNumber);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("data", order);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("주문 추적 실패 - 추적 번호: {}, 오류: {}", trackingNumber, e.getMessage());
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "해당 추적 번호의 주문을 찾을 수 없습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.NOT_FOUND).body(errorResponse);
        }
    }

    /**
     * 주문 통계 조회
     */
    @GetMapping("/statistics")
    @Timed(name = "orders.statistics", description = "Time taken to get order statistics")
    public ResponseEntity<Map<String, Object>> getOrderStatistics() {
        logger.debug("주문 통계 조회 요청");

        try {
            List<Object[]> statistics = orderService.getOrderStatistics();

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("data", statistics);

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("주문 통계 조회 실패 - 오류: {}", e.getMessage(), e);
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "주문 통계 조회에 실패했습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 기간별 매출 조회
     */
    @GetMapping("/revenue")
    @Timed(name = "orders.revenue", description = "Time taken to get revenue data")
    public ResponseEntity<Map<String, Object>> getRevenue(
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime startDate,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) LocalDateTime endDate) {

        logger.debug("매출 조회 요청 - 시작: {}, 종료: {}", startDate, endDate);

        try {
            Double revenue = orderService.getRevenueBetween(startDate, endDate);

            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("data", Map.of(
                "startDate", startDate,
                "endDate", endDate,
                "totalRevenue", revenue != null ? revenue : 0.0
            ));

            return ResponseEntity.ok(response);

        } catch (Exception e) {
            logger.error("매출 조회 실패 - 오류: {}", e.getMessage(), e);
            
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("success", false);
            errorResponse.put("message", "매출 조회에 실패했습니다: " + e.getMessage());

            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(errorResponse);
        }
    }

    /**
     * 헬스체크 엔드포인트
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "UP");
        response.put("service", "Order Service");
        response.put("timestamp", LocalDateTime.now());
        
        return ResponseEntity.ok(response);
    }
}