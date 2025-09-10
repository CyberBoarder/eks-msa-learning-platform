package com.eksmsa.learning.orderservice.dto;

import jakarta.validation.constraints.*;

import java.math.BigDecimal;

public class OrderItemRequest {

    @NotBlank(message = "상품 ID는 필수입니다")
    @Size(max = 50, message = "상품 ID는 50자를 초과할 수 없습니다")
    private String productId;

    @NotBlank(message = "상품명은 필수입니다")
    @Size(max = 200, message = "상품명은 200자를 초과할 수 없습니다")
    private String productName;

    @Size(max = 100, message = "상품 SKU는 100자를 초과할 수 없습니다")
    private String productSku;

    @Size(max = 500, message = "상품 이미지 URL은 500자를 초과할 수 없습니다")
    private String productImageUrl;

    @NotNull(message = "단가는 필수입니다")
    @DecimalMin(value = "0.0", inclusive = false, message = "단가는 0보다 커야 합니다")
    private BigDecimal unitPrice;

    @NotNull(message = "수량은 필수입니다")
    @Min(value = 1, message = "수량은 1 이상이어야 합니다")
    private Integer quantity;

    @DecimalMin(value = "0.0", inclusive = true, message = "할인 금액은 0 이상이어야 합니다")
    private BigDecimal discountAmount;

    @DecimalMin(value = "0.0", inclusive = true, message = "세금 금액은 0 이상이어야 합니다")
    private BigDecimal taxAmount;

    @Size(max = 500, message = "상품 메모는 500자를 초과할 수 없습니다")
    private String notes;

    // Constructors
    public OrderItemRequest() {}

    public OrderItemRequest(String productId, String productName, BigDecimal unitPrice, Integer quantity) {
        this.productId = productId;
        this.productName = productName;
        this.unitPrice = unitPrice;
        this.quantity = quantity;
    }

    // Getters and Setters
    public String getProductId() { return productId; }
    public void setProductId(String productId) { this.productId = productId; }

    public String getProductName() { return productName; }
    public void setProductName(String productName) { this.productName = productName; }

    public String getProductSku() { return productSku; }
    public void setProductSku(String productSku) { this.productSku = productSku; }

    public String getProductImageUrl() { return productImageUrl; }
    public void setProductImageUrl(String productImageUrl) { this.productImageUrl = productImageUrl; }

    public BigDecimal getUnitPrice() { return unitPrice; }
    public void setUnitPrice(BigDecimal unitPrice) { this.unitPrice = unitPrice; }

    public Integer getQuantity() { return quantity; }
    public void setQuantity(Integer quantity) { this.quantity = quantity; }

    public BigDecimal getDiscountAmount() { return discountAmount; }
    public void setDiscountAmount(BigDecimal discountAmount) { this.discountAmount = discountAmount; }

    public BigDecimal getTaxAmount() { return taxAmount; }
    public void setTaxAmount(BigDecimal taxAmount) { this.taxAmount = taxAmount; }

    public String getNotes() { return notes; }
    public void setNotes(String notes) { this.notes = notes; }
}