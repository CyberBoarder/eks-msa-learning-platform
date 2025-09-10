package com.eksmsa.learning.orderservice.repository;

import com.eksmsa.learning.orderservice.entity.Order;
import com.eksmsa.learning.orderservice.entity.OrderStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

@Repository
public interface OrderRepository extends JpaRepository<Order, String> {

    // 고객별 주문 조회
    Page<Order> findByCustomerId(String customerId, Pageable pageable);

    // 상태별 주문 조회
    Page<Order> findByStatus(OrderStatus status, Pageable pageable);

    // 고객 및 상태별 주문 조회
    Page<Order> findByCustomerIdAndStatus(String customerId, OrderStatus status, Pageable pageable);

    // 기간별 주문 조회
    @Query("SELECT o FROM Order o WHERE o.createdAt BETWEEN :startDate AND :endDate")
    Page<Order> findByCreatedAtBetween(
        @Param("startDate") LocalDateTime startDate, 
        @Param("endDate") LocalDateTime endDate, 
        Pageable pageable
    );

    // 고객별 최근 주문 조회
    @Query("SELECT o FROM Order o WHERE o.customerId = :customerId ORDER BY o.createdAt DESC")
    List<Order> findRecentOrdersByCustomerId(@Param("customerId") String customerId, Pageable pageable);

    // 상태별 주문 수 조회
    long countByStatus(OrderStatus status);

    // 고객별 주문 수 조회
    long countByCustomerId(String customerId);

    // 특정 기간 내 주문 수 조회
    @Query("SELECT COUNT(o) FROM Order o WHERE o.createdAt BETWEEN :startDate AND :endDate")
    long countByCreatedAtBetween(
        @Param("startDate") LocalDateTime startDate, 
        @Param("endDate") LocalDateTime endDate
    );

    // 활성 주문 조회 (취소되지 않은 주문)
    @Query("SELECT o FROM Order o WHERE o.status NOT IN ('CANCELLED', 'REFUNDED')")
    Page<Order> findActiveOrders(Pageable pageable);

    // 고객의 활성 주문 조회
    @Query("SELECT o FROM Order o WHERE o.customerId = :customerId AND o.status NOT IN ('CANCELLED', 'REFUNDED')")
    List<Order> findActiveOrdersByCustomerId(@Param("customerId") String customerId);

    // 배송 추적 번호로 주문 조회
    Optional<Order> findByTrackingNumber(String trackingNumber);

    // 고객 이메일로 주문 조회
    Page<Order> findByCustomerEmail(String customerEmail, Pageable pageable);

    // 특정 상품이 포함된 주문 조회
    @Query("SELECT DISTINCT o FROM Order o JOIN o.items i WHERE i.productId = :productId")
    Page<Order> findOrdersContainingProduct(@Param("productId") String productId, Pageable pageable);

    // 총 매출액 조회 (특정 기간)
    @Query("SELECT COALESCE(SUM(o.finalAmount), 0) FROM Order o WHERE o.status = 'DELIVERED' AND o.createdAt BETWEEN :startDate AND :endDate")
    Double getTotalRevenueBetween(
        @Param("startDate") LocalDateTime startDate, 
        @Param("endDate") LocalDateTime endDate
    );

    // 일별 주문 통계
    @Query("SELECT DATE(o.createdAt) as orderDate, COUNT(o) as orderCount, COALESCE(SUM(o.finalAmount), 0) as totalAmount " +
           "FROM Order o WHERE o.createdAt BETWEEN :startDate AND :endDate " +
           "GROUP BY DATE(o.createdAt) ORDER BY DATE(o.createdAt)")
    List<Object[]> getDailyOrderStatistics(
        @Param("startDate") LocalDateTime startDate, 
        @Param("endDate") LocalDateTime endDate
    );

    // 상태별 주문 통계
    @Query("SELECT o.status, COUNT(o) FROM Order o GROUP BY o.status")
    List<Object[]> getOrderStatusStatistics();

    // 고객별 주문 통계
    @Query("SELECT o.customerId, o.customerName, COUNT(o) as orderCount, COALESCE(SUM(o.finalAmount), 0) as totalAmount " +
           "FROM Order o GROUP BY o.customerId, o.customerName " +
           "ORDER BY totalAmount DESC")
    List<Object[]> getCustomerOrderStatistics(Pageable pageable);
}