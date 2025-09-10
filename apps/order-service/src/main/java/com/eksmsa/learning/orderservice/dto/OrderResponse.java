package com.eksmsa.learning.orderservice.dto;

import com.eksmsa.learning.orderservice.entity.OrderStatus;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;

public class OrderResponse {

    private String id;
    private String customerId;
    private String customerName;
    private String customerEmail;
    private String customerPhone;
    private OrderStatus status;
    private String statusDescription;
    private BigDecimal totalAmount;
    private BigDecimal discountAmount;
    private BigDecimal taxAmount;
    private BigDecimal shippingAmount;
    private BigDecimal finalAmount;
    private String currency;
    private String paymentMethod;
    private String paymentStatus;
    private String shippingAddress;
    private String billingAddress;
    private String notes;
    private String trackingNumber;
    private LocalDateTime estimatedDeliveryDate;
    private LocalDateTime deliveredAt;
    private LocalDateTime createdAt;
    private LocalDateTime updatedAt;
    private List<OrderItemResponse> items;
    private List<OrderStatusHistoryResponse> statusHistory;

    // Constructors
    public OrderResponse() {}

    // Getters and Setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }

    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public String getCustomerPhone() { return customerPhone; }
    public void setCustomerPhone(String customerPhone) { this.customerPhone = customerPhone; }

    public OrderStatus getStatus() { return status; }
    public void setStatus(OrderStatus status) { 
        this.status = status;
        this.statusDescription = status != null ? status.getDescription() : null;
    }

    public String getStatusDescription() { return statusDescription; }
    public void setStatusDescription(String statusDescription) { this.statusDescription = statusDescription; }

    public BigDecimal getTotalAmount() { return totalAmount; }
    public void setTotalAmount(BigDecimal totalAmount) { this.totalAmount = totalAmount; }

    public BigDecimal getDiscountAmount() { return discountAmount; }
    public void setDiscountAmount(BigDecimal discountAmount) { this.discountAmount = discountAmount; }

    public BigDecimal getTaxAmount() { return taxAmount; }
    public void setTaxAmount(BigDecimal taxAmount) { this.taxAmount = taxAmount; }

    public BigDecimal getShippingAmount() { return shippingAmount; }
    public void setShippingAmount(BigDecimal shippingAmount) { this.shippingAmount = shippingAmount; }

    public BigDecimal getFinalAmount() { return finalAmount; }
    public void setFinalAmount(BigDecimal finalAmount) { this.finalAmount = finalAmount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getPaymentStatus() { return paymentStatus; }
    public void setPaymentStatus(String paymentStatus) { this.paymentStatus = paymentStatus; }

    public String getShippingAddress() { return shippingAddress; }
    public void setShippingAddress(String shippingAddress) { this.shippingAddress = shippingAddress; }

    public String getBillingAddress() { return billingAddress; }
    public void setBillingAddress(String billingAddress) { this.billingAddress = billingAddress; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }

    public String getTrackingNumber() { return trackingNumber; }
    public void setTrackingNumber(String trackingNumber) { this.trackingNumber = trackingNumber; }

    public LocalDateTime getEstimatedDeliveryDate() { return estimatedDeliveryDate; }
    public void setEstimatedDeliveryDate(LocalDateTime estimatedDeliveryDate) { 
        this.estimatedDeliveryDate = estimatedDeliveryDate; 
    }

    public LocalDateTime getDeliveredAt() { return deliveredAt; }
    public void setDeliveredAt(LocalDateTime deliveredAt) { this.deliveredAt = deliveredAt; }

    public LocalDateTime getCreatedAt() { return createdAt; }
    public void setCreatedAt(LocalDateTime createdAt) { this.createdAt = createdAt; }

    public LocalDateTime getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(LocalDateTime updatedAt) { this.updatedAt = updatedAt; }

    public List<OrderItemResponse> getItems() { return items; }
    public void setItems(List<OrderItemResponse> items) { this.items = items; }

    public List<OrderStatusHistoryResponse> getStatusHistory() { return statusHistory; }
    public void setStatusHistory(List<OrderStatusHistoryResponse> statusHistory) { this.statusHistory = statusHistory; }
}