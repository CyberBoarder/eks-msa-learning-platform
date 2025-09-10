package com.eksmsa.learning.orderservice.service;

import com.eksmsa.learning.orderservice.dto.OrderItemRequest;
import com.eksmsa.learning.orderservice.entity.OrderItem;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;

@Service
public class OrderItemService {

    private static final Logger logger = LoggerFactory.getLogger(OrderItemService.class);

    /**
     * OrderItemRequest로부터 OrderItem 엔티티 생성
     */
    public OrderItem createOrderItem(OrderItemRequest request) {
        logger.debug("주문 상품 생성 - 상품 ID: {}, 수량: {}", request.getProductId(), request.getQuantity());

        OrderItem item = new OrderItem();
        item.setProductId(request.getProductId());
        item.setProductName(request.getProductName());
        item.setProductSku(request.getProductSku());
        item.setProductImageUrl(request.getProductImageUrl());
        item.setUnitPrice(request.getUnitPrice());
        item.setQuantity(request.getQuantity());
        item.setNotes(request.getNotes());

        // 할인 및 세금 설정
        if (request.getDiscountAmount() != null) {
            item.setDiscountAmount(request.getDiscountAmount());
        }
        if (request.getTaxAmount() != null) {
            item.setTaxAmount(request.getTaxAmount());
        }

        // 소계 계산
        item.calculateSubtotal();

        logger.debug("주문 상품 생성 완료 - 상품: {}, 소계: {}", item.getProductName(), item.getSubtotal());

        return item;
    }

    /**
     * 주문 상품 수량 업데이트
     */
    public void updateQuantity(OrderItem item, Integer newQuantity) {
        logger.debug("주문 상품 수량 변경 - 상품 ID: {}, 기존 수량: {}, 새 수량: {}", 
            item.getProductId(), item.getQuantity(), newQuantity);

        if (newQuantity <= 0) {
            throw new IllegalArgumentException("수량은 1 이상이어야 합니다");
        }

        item.updateQuantity(newQuantity);
        
        logger.debug("주문 상품 수량 변경 완료 - 새 소계: {}", item.getSubtotal());
    }

    /**
     * 주문 상품 단가 업데이트
     */
    public void updateUnitPrice(OrderItem item, BigDecimal newUnitPrice) {
        logger.debug("주문 상품 단가 변경 - 상품 ID: {}, 기존 단가: {}, 새 단가: {}", 
            item.getProductId(), item.getUnitPrice(), newUnitPrice);

        if (newUnitPrice.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("단가는 0보다 커야 합니다");
        }

        item.updateUnitPrice(newUnitPrice);
        
        logger.debug("주문 상품 단가 변경 완료 - 새 소계: {}", item.getSubtotal());
    }

    /**
     * 주문 상품 할인 적용
     */
    public void applyDiscount(OrderItem item, BigDecimal discountAmount) {
        logger.debug("주문 상품 할인 적용 - 상품 ID: {}, 할인 금액: {}", 
            item.getProductId(), discountAmount);

        if (discountAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("할인 금액은 0 이상이어야 합니다");
        }

        if (discountAmount.compareTo(item.getSubtotal()) > 0) {
            throw new IllegalArgumentException("할인 금액은 소계를 초과할 수 없습니다");
        }

        item.setDiscountAmount(discountAmount);
        
        logger.debug("주문 상품 할인 적용 완료 - 최종 금액: {}", item.getFinalAmount());
    }

    /**
     * 주문 상품 세금 적용
     */
    public void applyTax(OrderItem item, BigDecimal taxAmount) {
        logger.debug("주문 상품 세금 적용 - 상품 ID: {}, 세금 금액: {}", 
            item.getProductId(), taxAmount);

        if (taxAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("세금 금액은 0 이상이어야 합니다");
        }

        item.setTaxAmount(taxAmount);
        
        logger.debug("주문 상품 세금 적용 완료 - 최종 금액: {}", item.getFinalAmount());
    }

    /**
     * 주문 상품 유효성 검증
     */
    public void validateOrderItem(OrderItemRequest request) {
        if (request.getProductId() == null || request.getProductId().trim().isEmpty()) {
            throw new IllegalArgumentException("상품 ID는 필수입니다");
        }

        if (request.getProductName() == null || request.getProductName().trim().isEmpty()) {
            throw new IllegalArgumentException("상품명은 필수입니다");
        }

        if (request.getUnitPrice() == null || request.getUnitPrice().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("단가는 0보다 커야 합니다");
        }

        if (request.getQuantity() == null || request.getQuantity() <= 0) {
            throw new IllegalArgumentException("수량은 1 이상이어야 합니다");
        }

        // 할인 금액 검증
        if (request.getDiscountAmount() != null && request.getDiscountAmount().compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("할인 금액은 0 이상이어야 합니다");
        }

        // 세금 금액 검증
        if (request.getTaxAmount() != null && request.getTaxAmount().compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("세금 금액은 0 이상이어야 합니다");
        }

        logger.debug("주문 상품 유효성 검증 완료 - 상품 ID: {}", request.getProductId());
    }
}