package com.eksmsa.learning.orderservice.dto;

import com.eksmsa.learning.orderservice.entity.OrderStatus;

import java.time.LocalDateTime;

public class OrderStatusHistoryResponse {

    private Long id;
    private OrderStatus fromStatus;
    private String fromStatusDescription;
    private OrderStatus toStatus;
    private String toStatusDescription;
    private String reason;
    private String changedBy;
    private LocalDateTime changedAt;

    // Constructors
    public OrderStatusHistoryResponse() {}

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public OrderStatus getFromStatus() { return fromStatus; }
    public void setFromStatus(OrderStatus fromStatus) { 
        this.fromStatus = fromStatus;
        this.fromStatusDescription = fromStatus != null ? fromStatus.getDescription() : null;
    }

    public String getFromStatusDescription() { return fromStatusDescription; }
    public void setFromStatusDescription(String fromStatusDescription) { this.fromStatusDescription = fromStatusDescription; }

    public OrderStatus getToStatus() { return toStatus; }
    public void setToStatus(OrderStatus toStatus) { 
        this.toStatus = toStatus;
        this.toStatusDescription = toStatus != null ? toStatus.getDescription() : null;
    }

    public String getToStatusDescription() { return toStatusDescription; }
    public void setToStatusDescription(String toStatusDescription) { this.toStatusDescription = toStatusDescription; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getChangedBy() { return changedBy; }
    public void setChangedBy(String changedBy) { this.changedBy = changedBy; }

    public LocalDateTime getChangedAt() { return changedAt; }
    public void setChangedAt(LocalDateTime changedAt) { this.changedAt = changedAt; }
}