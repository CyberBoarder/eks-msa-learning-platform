package com.eksmsa.learning.orderservice.listener;

import com.eksmsa.learning.orderservice.event.OrderEvent;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.redis.connection.Message;
import org.springframework.data.redis.connection.MessageListener;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Component;

@Component
public class OrderEventListener implements MessageListener {

    private static final Logger logger = LoggerFactory.getLogger(OrderEventListener.class);

    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;

    @Autowired
    public OrderEventListener(RedisTemplate<String, Object> redisTemplate) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = new ObjectMapper();
        this.objectMapper.registerModule(new JavaTimeModule());
    }

    @Override
    public void onMessage(Message message, byte[] pattern) {
        try {
            String channel = new String(message.getChannel());
            String messageBody = new String(message.getBody());
            
            logger.debug("Redis 메시지 수신 - 채널: {}, 메시지: {}", channel, messageBody);

            // 메시지를 OrderEvent로 역직렬화
            OrderEvent event = objectMapper.readValue(messageBody, OrderEvent.class);
            
            // 채널별로 처리
            switch (channel) {
                case "order.events":
                    handleOrderEvent(event);
                    break;
                case "order.notifications":
                    handleOrderNotification(event);
                    break;
                case "order.analytics":
                    handleOrderAnalytics(event);
                    break;
                default:
                    logger.warn("알 수 없는 채널에서 메시지 수신: {}", channel);
            }

        } catch (Exception e) {
            logger.error("Redis 메시지 처리 실패 - 오류: {}", e.getMessage(), e);
        }
    }

    /**
     * 주문 이벤트 처리
     */
    private void handleOrderEvent(OrderEvent event) {
        logger.info("주문 이벤트 처리 - 이벤트 ID: {}, 타입: {}, 주문 ID: {}", 
            event.getEventId(), event.getEventType(), event.getOrderId());

        try {
            // 이벤트 타입별 처리
            switch (event.getEventType()) {
                case OrderEvent.ORDER_CREATED:
                    handleOrderCreated(event);
                    break;
                case OrderEvent.ORDER_STATUS_CHANGED:
                    handleOrderStatusChanged(event);
                    break;
                case OrderEvent.ORDER_CANCELLED:
                    handleOrderCancelled(event);
                    break;
                case OrderEvent.ORDER_SHIPPED:
                    handleOrderShipped(event);
                    break;
                case OrderEvent.ORDER_DELIVERED:
                    handleOrderDelivered(event);
                    break;
                default:
                    logger.warn("알 수 없는 이벤트 타입: {}", event.getEventType());
            }

            // 이벤트 처리 성공 로그
            logger.debug("주문 이벤트 처리 완료 - 이벤트 ID: {}", event.getEventId());

        } catch (Exception e) {
            logger.error("주문 이벤트 처리 실패 - 이벤트 ID: {}, 오류: {}", 
                event.getEventId(), e.getMessage(), e);
        }
    }

    /**
     * 주문 생성 이벤트 처리
     */
    private void handleOrderCreated(OrderEvent event) {
        logger.info("주문 생성 이벤트 처리 - 주문 ID: {}, 고객: {}", 
            event.getOrderId(), event.getCustomerId());

        // 주문 생성 후 처리 로직
        // 예: 재고 확인, 결제 처리 요청, 고객 알림 등
        
        // 주문 통계 업데이트
        updateOrderStatistics(event);
        
        // 고객별 주문 수 업데이트
        updateCustomerOrderCount(event.getCustomerId());
    }

    /**
     * 주문 상태 변경 이벤트 처리
     */
    private void handleOrderStatusChanged(OrderEvent event) {
        logger.info("주문 상태 변경 이벤트 처리 - 주문 ID: {}, 상태: {} -> {}", 
            event.getOrderId(), event.getPreviousStatus(), event.getOrderStatus());

        // 상태별 후처리 로직
        switch (event.getOrderStatus()) {
            case CONFIRMED:
                handleOrderConfirmed(event);
                break;
            case PROCESSING:
                handleOrderProcessing(event);
                break;
            case SHIPPED:
                handleOrderShipped(event);
                break;
            case DELIVERED:
                handleOrderDelivered(event);
                break;
            case CANCELLED:
                handleOrderCancelled(event);
                break;
        }
    }

    /**
     * 주문 확인 처리
     */
    private void handleOrderConfirmed(OrderEvent event) {
        logger.info("주문 확인 처리 - 주문 ID: {}", event.getOrderId());
        // 재고 차감, 결제 승인 등
    }

    /**
     * 주문 처리 중 처리
     */
    private void handleOrderProcessing(OrderEvent event) {
        logger.info("주문 처리 중 - 주문 ID: {}", event.getOrderId());
        // 상품 준비, 포장 지시 등
    }

    /**
     * 주문 배송 시작 처리
     */
    private void handleOrderShipped(OrderEvent event) {
        logger.info("주문 배송 시작 처리 - 주문 ID: {}", event.getOrderId());
        // 배송 추적 정보 등록, 고객 알림 등
    }

    /**
     * 주문 배송 완료 처리
     */
    private void handleOrderDelivered(OrderEvent event) {
        logger.info("주문 배송 완료 처리 - 주문 ID: {}", event.getOrderId());
        // 매출 확정, 리뷰 요청 등
        updateRevenueStatistics(event);
    }

    /**
     * 주문 취소 처리
     */
    private void handleOrderCancelled(OrderEvent event) {
        logger.info("주문 취소 처리 - 주문 ID: {}", event.getOrderId());
        // 재고 복구, 환불 처리 등
    }

    /**
     * 주문 알림 처리
     */
    private void handleOrderNotification(OrderEvent event) {
        logger.info("주문 알림 처리 - 이벤트 ID: {}, 고객: {}", 
            event.getEventId(), event.getCustomerId());

        // 고객 알림 발송 로직
        // 예: 이메일, SMS, 푸시 알림 등
        
        // 알림 히스토리 저장
        storeNotificationHistory(event);
    }

    /**
     * 주문 분석 데이터 처리
     */
    private void handleOrderAnalytics(OrderEvent event) {
        logger.debug("주문 분석 데이터 처리 - 이벤트 ID: {}", event.getEventId());

        // 분석 데이터 수집 및 저장
        // 예: 주문 패턴 분석, 고객 행동 분석 등
        
        // 실시간 대시보드 데이터 업데이트
        updateDashboardMetrics(event);
    }

    /**
     * 주문 통계 업데이트
     */
    private void updateOrderStatistics(OrderEvent event) {
        try {
            String dailyOrderKey = "stats:orders:daily:" + 
                java.time.LocalDate.now().toString();
            redisTemplate.opsForValue().increment(dailyOrderKey);
            redisTemplate.expire(dailyOrderKey, java.time.Duration.ofDays(90));

            String monthlyOrderKey = "stats:orders:monthly:" + 
                java.time.YearMonth.now().toString();
            redisTemplate.opsForValue().increment(monthlyOrderKey);
            redisTemplate.expire(monthlyOrderKey, java.time.Duration.ofDays(365));

        } catch (Exception e) {
            logger.error("주문 통계 업데이트 실패: {}", e.getMessage());
        }
    }

    /**
     * 고객별 주문 수 업데이트
     */
    private void updateCustomerOrderCount(String customerId) {
        try {
            String customerOrderKey = "stats:customer:orders:" + customerId;
            redisTemplate.opsForValue().increment(customerOrderKey);
            redisTemplate.expire(customerOrderKey, java.time.Duration.ofDays(365));

        } catch (Exception e) {
            logger.error("고객 주문 수 업데이트 실패: {}", e.getMessage());
        }
    }

    /**
     * 매출 통계 업데이트
     */
    private void updateRevenueStatistics(OrderEvent event) {
        try {
            if (event.getTotalAmount() != null) {
                String dailyRevenueKey = "stats:revenue:daily:" + 
                    java.time.LocalDate.now().toString();
                redisTemplate.opsForValue().increment(dailyRevenueKey, 
                    event.getTotalAmount().doubleValue());
                redisTemplate.expire(dailyRevenueKey, java.time.Duration.ofDays(90));
            }

        } catch (Exception e) {
            logger.error("매출 통계 업데이트 실패: {}", e.getMessage());
        }
    }

    /**
     * 알림 히스토리 저장
     */
    private void storeNotificationHistory(OrderEvent event) {
        try {
            String notificationKey = "notifications:order:" + event.getOrderId() + 
                ":" + System.currentTimeMillis();
            redisTemplate.opsForValue().set(notificationKey, event, 
                java.time.Duration.ofDays(30));

        } catch (Exception e) {
            logger.error("알림 히스토리 저장 실패: {}", e.getMessage());
        }
    }

    /**
     * 대시보드 메트릭 업데이트
     */
    private void updateDashboardMetrics(OrderEvent event) {
        try {
            // 실시간 주문 수
            String realtimeOrderKey = "metrics:realtime:orders";
            redisTemplate.opsForValue().increment(realtimeOrderKey);
            redisTemplate.expire(realtimeOrderKey, java.time.Duration.ofMinutes(5));

            // 상태별 주문 수
            if (event.getOrderStatus() != null) {
                String statusKey = "metrics:orders:status:" + event.getOrderStatus().name();
                redisTemplate.opsForValue().increment(statusKey);
                redisTemplate.expire(statusKey, java.time.Duration.ofHours(1));
            }

        } catch (Exception e) {
            logger.error("대시보드 메트릭 업데이트 실패: {}", e.getMessage());
        }
    }
}