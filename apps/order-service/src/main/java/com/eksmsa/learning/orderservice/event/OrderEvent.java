package com.eksmsa.learning.orderservice.event;

import com.eksmsa.learning.orderservice.entity.OrderStatus;
import com.fasterxml.jackson.annotation.JsonFormat;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class OrderEvent {

    private String eventId;
    private String eventType;
    private String orderId;
    private String customerId;
    private String customerName;
    private OrderStatus orderStatus;
    private OrderStatus previousStatus;
    private BigDecimal totalAmount;
    private String currency;
    private String reason;
    private String changedBy;
    
    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime timestamp;

    // Constructors
    public OrderEvent() {
        this.timestamp = LocalDateTime.now();
    }

    public OrderEvent(String eventType, String orderId) {
        this();
        this.eventType = eventType;
        this.orderId = orderId;
        this.eventId = generateEventId();
    }

    // Event Types
    public static final String ORDER_CREATED = "ORDER_CREATED";
    public static final String ORDER_STATUS_CHANGED = "ORDER_STATUS_CHANGED";
    public static final String ORDER_CANCELLED = "ORDER_CANCELLED";
    public static final String ORDER_SHIPPED = "ORDER_SHIPPED";
    public static final String ORDER_DELIVERED = "ORDER_DELIVERED";

    // Business Methods
    public static OrderEvent orderCreated(String orderId, String customerId, String customerName, 
                                        BigDecimal totalAmount, String currency) {
        OrderEvent event = new OrderEvent(ORDER_CREATED, orderId);
        event.setCustomerId(customerId);
        event.setCustomerName(customerName);
        event.setOrderStatus(OrderStatus.PENDING);
        event.setTotalAmount(totalAmount);
        event.setCurrency(currency);
        return event;
    }

    public static OrderEvent orderStatusChanged(String orderId, String customerId, 
                                              OrderStatus previousStatus, OrderStatus newStatus,
                                              String reason, String changedBy) {
        OrderEvent event = new OrderEvent(ORDER_STATUS_CHANGED, orderId);
        event.setCustomerId(customerId);
        event.setPreviousStatus(previousStatus);
        event.setOrderStatus(newStatus);
        event.setReason(reason);
        event.setChangedBy(changedBy);
        return event;
    }

    public static OrderEvent orderCancelled(String orderId, String customerId, 
                                          String reason, String cancelledBy) {
        OrderEvent event = new OrderEvent(ORDER_CANCELLED, orderId);
        event.setCustomerId(customerId);
        event.setOrderStatus(OrderStatus.CANCELLED);
        event.setReason(reason);
        event.setChangedBy(cancelledBy);
        return event;
    }

    public static OrderEvent orderShipped(String orderId, String customerId, String trackingNumber) {
        OrderEvent event = new OrderEvent(ORDER_SHIPPED, orderId);
        event.setCustomerId(customerId);
        event.setOrderStatus(OrderStatus.SHIPPED);
        event.setReason("배송 시작 - 추적번호: " + trackingNumber);
        return event;
    }

    public static OrderEvent orderDelivered(String orderId, String customerId) {
        OrderEvent event = new OrderEvent(ORDER_DELIVERED, orderId);
        event.setCustomerId(customerId);
        event.setOrderStatus(OrderStatus.DELIVERED);
        event.setReason("배송 완료");
        return event;
    }

    private String generateEventId() {
        return "EVT-" + System.currentTimeMillis() + "-" + 
               java.util.UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }

    // Getters and Setters
    public String getEventId() { return eventId; }
    public void setEventId(String eventId) { this.eventId = eventId; }

    public String getEventType() { return eventType; }
    public void setEventType(String eventType) { this.eventType = eventType; }

    public String getOrderId() { return orderId; }
    public void setOrderId(String orderId) { this.orderId = orderId; }

    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public OrderStatus getOrderStatus() { return orderStatus; }
    public void setOrderStatus(OrderStatus orderStatus) { this.orderStatus = orderStatus; }

    public OrderStatus getPreviousStatus() { return previousStatus; }
    public void setPreviousStatus(OrderStatus previousStatus) { this.previousStatus = previousStatus; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getChangedBy() { return changedBy; }
    public void setChangedBy(String changedBy) { this.changedBy = changedBy; }

    public LocalDateTime getTimestamp() { return timestamp; }
    public void setTimestamp(LocalDateTime timestamp) { this.timestamp = timestamp; }

    @Override
    public String toString() {
        return "OrderEvent{" +
                "eventId='" + eventId + '\'' +
                ", eventType='" + eventType + '\'' +
                ", orderId='" + orderId + '\'' +
                ", customerId='" + customerId + '\'' +
                ", orderStatus=" + orderStatus +
                ", timestamp=" + timestamp +
                '}';
    }
}