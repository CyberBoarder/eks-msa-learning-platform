package com.eksmsa.learning.orderservice.entity;

public enum OrderStatus {
    PENDING("대기중"),
    CONFIRMED("확인됨"),
    PROCESSING("처리중"),
    SHIPPED("배송중"),
    DELIVERED("배송완료"),
    CANCELLED("취소됨"),
    REFUNDED("환불됨");

    private final String description;

    OrderStatus(String description) {
        this.description = description;
    }

    public String getDescription() {
        return description;
    }

    public boolean isActive() {
        return this != CANCELLED && this != REFUNDED;
    }

    public boolean canTransitionTo(OrderStatus newStatus) {
        switch (this) {
            case PENDING:
                return newStatus == CONFIRMED || newStatus == CANCELLED;
            case CONFIRMED:
                return newStatus == PROCESSING || newStatus == CANCELLED;
            case PROCESSING:
                return newStatus == SHIPPED || newStatus == CANCELLED;
            case SHIPPED:
                return newStatus == DELIVERED;
            case DELIVERED:
                return newStatus == REFUNDED;
            case CANCELLED:
            case REFUNDED:
                return false;
            default:
                return false;
        }
    }
}