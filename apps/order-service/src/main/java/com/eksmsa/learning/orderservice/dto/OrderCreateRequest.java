package com.eksmsa.learning.orderservice.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

import java.math.BigDecimal;
import java.util.List;

public class OrderCreateRequest {

    @NotBlank(message = "고객 ID는 필수입니다")
    @Size(max = 50, message = "고객 ID는 50자를 초과할 수 없습니다")
    private String customerId;

    @NotBlank(message = "고객 이름은 필수입니다")
    @Size(max = 100, message = "고객 이름은 100자를 초과할 수 없습니다")
    private String customerName;

    @Email(message = "유효한 이메일 주소를 입력해주세요")
    @Size(max = 100, message = "이메일은 100자를 초과할 수 없습니다")
    private String customerEmail;

    @Size(max = 20, message = "전화번호는 20자를 초과할 수 없습니다")
    private String customerPhone;

    @NotEmpty(message = "주문 상품은 최소 1개 이상이어야 합니다")
    @Valid
    private List<OrderItemRequest> items;

    @DecimalMin(value = "0.0", inclusive = true, message = "할인 금액은 0 이상이어야 합니다")
    private BigDecimal discountAmount;

    @DecimalMin(value = "0.0", inclusive = true, message = "세금 금액은 0 이상이어야 합니다")
    private BigDecimal taxAmount;

    @DecimalMin(value = "0.0", inclusive = true, message = "배송비는 0 이상이어야 합니다")
    private BigDecimal shippingAmount;

    @Size(max = 3, message = "통화 코드는 3자여야 합니다")
    private String currency = "KRW";

    @Size(max = 50, message = "결제 방법은 50자를 초과할 수 없습니다")
    private String paymentMethod;

    @Size(max = 1000, message = "배송 주소는 1000자를 초과할 수 없습니다")
    private String shippingAddress;

    @Size(max = 1000, message = "청구 주소는 1000자를 초과할 수 없습니다")
    private String billingAddress;

    @Size(max = 1000, message = "주문 메모는 1000자를 초과할 수 없습니다")
    private String notes;

    // Constructors
    public OrderCreateRequest() {}

    // Getters and Setters
    public String getCustomerId() { return customerId; }
    public void setCustomerId(String customerId) { this.customerId = customerId; }

    public String getCustomerName() { return customerName; }
    public void setCustomerName(String customerName) { this.customerName = customerName; }

    public String getCustomerEmail() { return customerEmail; }
    public void setCustomerEmail(String customerEmail) { this.customerEmail = customerEmail; }

    public String getCustomerPhone() { return customerPhone; }
    public void setCustomerPhone(String customerPhone) { this.customerPhone = customerPhone; }

    public List<OrderItemRequest> getItems() { return items; }
    public void setItems(List<OrderItemRequest> items) { this.items = items; }

    public BigDecimal getDiscountAmount() { return discountAmount; }
    public void setDiscountAmount(BigDecimal discountAmount) { this.discountAmount = discountAmount; }

    public BigDecimal getTaxAmount() { return taxAmount; }
    public void setTaxAmount(BigDecimal taxAmount) { this.taxAmount = taxAmount; }

    public BigDecimal getShippingAmount() { return shippingAmount; }
    public void setShippingAmount(BigDecimal shippingAmount) { this.shippingAmount = shippingAmount; }

    public String getCurrency() { return currency; }
    public void setCurrency(String currency) { this.currency = currency; }

    public String getPaymentMethod() { return paymentMethod; }
    public void setPaymentMethod(String paymentMethod) { this.paymentMethod = paymentMethod; }

    public String getShippingAddress() { return shippingAddress; }
    public void setShippingAddress(String shippingAddress) { this.shippingAddress = shippingAddress; }

    public String getBillingAddress() { return billingAddress; }
    public void setBillingAddress(String billingAddress) { this.billingAddress = billingAddress; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
}