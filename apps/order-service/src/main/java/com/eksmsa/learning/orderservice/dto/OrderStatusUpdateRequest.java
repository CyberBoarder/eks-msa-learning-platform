package com.eksmsa.learning.orderservice.dto;

import com.eksmsa.learning.orderservice.entity.OrderStatus;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public class OrderStatusUpdateRequest {

    @NotNull(message = "주문 상태는 필수입니다")
    private OrderStatus status;

    @Size(max = 500, message = "상태 변경 사유는 500자를 초과할 수 없습니다")
    private String reason;

    @Size(max = 100, message = "변경자 정보는 100자를 초과할 수 없습니다")
    private String changedBy;

    @Size(max = 100, message = "배송 추적 번호는 100자를 초과할 수 없습니다")
    private String trackingNumber;

    // Constructors
    public OrderStatusUpdateRequest() {}

    public OrderStatusUpdateRequest(OrderStatus status, String reason) {
        this.status = status;
        this.reason = reason;
    }

    // Getters and Setters
    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { this.status = status; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getChangedBy() { return changedBy; }
    public void setChangedBy(String changedBy) { this.changedBy = changedBy; }

    public String getTrackingNumber() { return trackingNumber; }
    public void setTrackingNumber(String trackingNumber) { this.trackingNumber = trackingNumber; }
}