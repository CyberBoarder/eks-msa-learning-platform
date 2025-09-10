package com.eksmsa.learning.orderservice.service;

import com.eksmsa.learning.orderservice.event.OrderEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;

@Service
public class OrderEventService {

    private static final Logger logger = LoggerFactory.getLogger(OrderEventService.class);

    // Redis 채널 이름
    public static final String ORDER_EVENTS_CHANNEL = "order.events";
    public static final String ORDER_NOTIFICATIONS_CHANNEL = "order.notifications";
    public static final String ORDER_ANALYTICS_CHANNEL = "order.analytics";

    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;

    @Autowired
    public OrderEventService(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    /**
     * 주문 이벤트 발행
     */
    public void publishOrderEvent(OrderEvent event) {
        try {
            String eventJson = objectMapper.writeValueAsString(event);
            
            // 메인 이벤트 채널에 발행
            redisTemplate.convertAndSend(ORDER_EVENTS_CHANNEL, eventJson);
            
            // 이벤트 타입에 따라 추가 채널에 발행
            publishToSpecificChannels(event, eventJson);
            
            logger.info("주문 이벤트 발행 완료 - 이벤트 ID: {}, 타입: {}, 주문 ID: {}", 
                event.getEventId(), event.getEventType(), event.getOrderId());

        } catch (JsonProcessingException e) {
            logger.error("주문 이벤트 직렬화 실패 - 이벤트 ID: {}, 오류: {}", 
                event.getEventId(), e.getMessage(), e);
            throw new RuntimeException("이벤트 발행에 실패했습니다", e);
        } catch (Exception e) {
            logger.error("주문 이벤트 발행 실패 - 이벤트 ID: {}, 오류: {}", 
                event.getEventId(), e.getMessage(), e);
            throw new RuntimeException("이벤트 발행에 실패했습니다", e);
        }
    }

    /**
     * 특정 채널에 이벤트 발행
     */
    private void publishToSpecificChannels(OrderEvent event, String eventJson) {
        switch (event.getEventType()) {
            case OrderEvent.ORDER_CREATED:
            case OrderEvent.ORDER_STATUS_CHANGED:
            case OrderEvent.ORDER_CANCELLED:
            case OrderEvent.ORDER_SHIPPED:
            case OrderEvent.ORDER_DELIVERED:
                // 알림 채널에 발행 (고객 알림용)
                redisTemplate.convertAndSend(ORDER_NOTIFICATIONS_CHANNEL, eventJson);
                break;
        }

        // 모든 이벤트를 분석 채널에 발행 (분석 및 모니터링용)
        redisTemplate.convertAndSend(ORDER_ANALYTICS_CHANNEL, eventJson);
    }

    /**
     * 주문 생성 이벤트 발행
     */
    public void publishOrderCreatedEvent(String orderId, String customerId, String customerName,
                                       java.math.BigDecimal totalAmount, String currency) {
        OrderEvent event = OrderEvent.orderCreated(orderId, customerId, customerName, totalAmount, currency);
        publishOrderEvent(event);
    }

    /**
     * 주문 상태 변경 이벤트 발행
     */
    public void publishOrderStatusChangedEvent(String orderId, String customerId,
                                             com.eksmsa.learning.orderservice.entity.OrderStatus previousStatus,
                                             com.eksmsa.learning.orderservice.entity.OrderStatus newStatus,
                                             String reason, String changedBy) {
        OrderEvent event = OrderEvent.orderStatusChanged(orderId, customerId, previousStatus, newStatus, reason, changedBy);
        publishOrderEvent(event);
    }

    /**
     * 주문 취소 이벤트 발행
     */
    public void publishOrderCancelledEvent(String orderId, String customerId, String reason, String cancelledBy) {
        OrderEvent event = OrderEvent.orderCancelled(orderId, customerId, reason, cancelledBy);
        publishOrderEvent(event);
    }

    /**
     * 주문 배송 시작 이벤트 발행
     */
    public void publishOrderShippedEvent(String orderId, String customerId, String trackingNumber) {
        OrderEvent event = OrderEvent.orderShipped(orderId, customerId, trackingNumber);
        publishOrderEvent(event);
    }

    /**
     * 주문 배송 완료 이벤트 발행
     */
    public void publishOrderDeliveredEvent(String orderId, String customerId) {
        OrderEvent event = OrderEvent.orderDelivered(orderId, customerId);
        publishOrderEvent(event);
    }

    /**
     * 이벤트 저장 (선택적 - 이벤트 소싱을 위한)
     */
    public void storeEvent(OrderEvent event) {
        try {
            String eventKey = "order:events:" + event.getOrderId() + ":" + event.getEventId();
            String eventJson = objectMapper.writeValueAsString(event);
            
            // 이벤트를 Redis에 저장 (TTL: 30일)
            redisTemplate.opsForValue().set(eventKey, eventJson, 
                java.time.Duration.ofDays(30));
            
            // 주문별 이벤트 리스트에 추가
            String orderEventsKey = "order:events:list:" + event.getOrderId();
            redisTemplate.opsForList().rightPush(orderEventsKey, event.getEventId());
            redisTemplate.expire(orderEventsKey, java.time.Duration.ofDays(30));
            
            logger.debug("이벤트 저장 완료 - 이벤트 ID: {}", event.getEventId());

        } catch (Exception e) {
            logger.error("이벤트 저장 실패 - 이벤트 ID: {}, 오류: {}", 
                event.getEventId(), e.getMessage(), e);
        }
    }

    /**
     * 주문별 이벤트 히스토리 조회
     */
    public java.util.List<OrderEvent> getOrderEventHistory(String orderId) {
        try {
            String orderEventsKey = "order:events:list:" + orderId;
            java.util.List<Object> eventIds = redisTemplate.opsForList().range(orderEventsKey, 0, -1);
            
            if (eventIds == null || eventIds.isEmpty()) {
                return java.util.Collections.emptyList();
            }

            java.util.List<OrderEvent> events = new java.util.ArrayList<>();
            for (Object eventId : eventIds) {
                String eventKey = "order:events:" + orderId + ":" + eventId.toString();
                String eventJson = (String) redisTemplate.opsForValue().get(eventKey);
                
                if (eventJson != null) {
                    OrderEvent event = objectMapper.readValue(eventJson, OrderEvent.class);
                    events.add(event);
                }
            }

            return events;

        } catch (Exception e) {
            logger.error("주문 이벤트 히스토리 조회 실패 - 주문 ID: {}, 오류: {}", 
                orderId, e.getMessage(), e);
            return java.util.Collections.emptyList();
        }
    }
}