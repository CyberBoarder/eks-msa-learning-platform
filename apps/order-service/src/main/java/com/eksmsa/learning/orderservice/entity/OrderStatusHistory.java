package com.eksmsa.learning.orderservice.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "order_status_history", indexes = {
    @Index(name = "idx_order_status_history_order_id", columnList = "order_id"),
    @Index(name = "idx_order_status_history_changed_at", columnList = "changed_at")
})
public class OrderStatusHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id", nullable = false)
    private Order order;

    @Enumerated(EnumType.STRING)
    @Column(name = "from_status", length = 20)
    private OrderStatus fromStatus;

    @Enumerated(EnumType.STRING)
    @Column(name = "to_status", nullable = false, length = 20)
    private OrderStatus toStatus;

    @Column(name = "changed_at", nullable = false)
    private LocalDateTime changedAt;

    @Column(name = "changed_by", length = 100)
    private String changedBy;

    @Column(name = "reason", columnDefinition = "TEXT")
    private String reason;

    @Column(name = "notes", columnDefinition = "TEXT")
    private String notes;

    // Constructors
    public OrderStatusHistory() {}

    public OrderStatusHistory(Order order, OrderStatus fromStatus, OrderStatus toStatus) {
        this.order = order;
        this.fromStatus = fromStatus;
        this.toStatus = toStatus;
        this.changedAt = LocalDateTime.now();
    }

    // Getters and Setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Order getOrder() { return order; }
    public void setOrder(Order order) { this.order = order; }

    public OrderStatus getFromStatus() { return fromStatus; }
    public void setFromStatus(OrderStatus fromStatus) { this.fromStatus = fromStatus; }

    public OrderStatus getToStatus() { return toStatus; }
    public void setToStatus(OrderStatus toStatus) { this.toStatus = toStatus; }

    public LocalDateTime getChangedAt() { return changedAt; }
    public void setChangedAt(LocalDateTime changedAt) { this.changedAt = changedAt; }

    public String getChangedBy() { return changedBy; }
    public void setChangedBy(String changedBy) { this.changedBy = changedBy; }

    public String getReason() { return reason; }
    public void setReason(String reason) { this.reason = reason; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
}