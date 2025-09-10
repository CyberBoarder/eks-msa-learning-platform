package com.eksmsa.learning.orderservice.controller;

import com.eksmsa.learning.orderservice.dto.OrderCreateRequest;
import com.eksmsa.learning.orderservice.dto.OrderItemRequest;
import com.eksmsa.learning.orderservice.dto.OrderStatusUpdateRequest;
import com.eksmsa.learning.orderservice.entity.OrderStatus;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureWebMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.context.WebApplicationContext;

import java.math.BigDecimal;
import java.util.Arrays;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureWebMvc
@ActiveProfiles("test")
@Transactional
class OrderControllerIntegrationTest {

    @Autowired
    private WebApplicationContext webApplicationContext;

    @Autowired
    private ObjectMapper objectMapper;

    private MockMvc mockMvc;

    @BeforeEach
    void setUp() {
        mockMvc = MockMvcBuilders.webAppContextSetup(webApplicationContext).build();
    }

    @Test
    void 주문_생성_API_테스트() throws Exception {
        // Given
        OrderCreateRequest request = new OrderCreateRequest();
        request.setCustomerId("CUST-001");
        request.setCustomerName("홍길동");
        request.setCustomerEmail("hong@example.com");
        request.setCustomerPhone("010-1234-5678");
        request.setCurrency("KRW");
        request.setPaymentMethod("CARD");
        request.setShippingAddress("서울시 강남구");

        OrderItemRequest itemRequest = new OrderItemRequest();
        itemRequest.setProductId("PROD-001");
        itemRequest.setProductName("테스트 상품");
        itemRequest.setUnitPrice(new BigDecimal("10000"));
        itemRequest.setQuantity(2);
        request.setItems(Arrays.asList(itemRequest));

        // When & Then
        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data.customerId").value("CUST-001"))
                .andExpect(jsonPath("$.data.customerName").value("홍길동"))
                .andExpect(jsonPath("$.data.status").value("PENDING"));
    }

    @Test
    void 주문_생성_유효성_검증_실패() throws Exception {
        // Given - 필수 필드 누락
        OrderCreateRequest request = new OrderCreateRequest();
        request.setCustomerId(""); // 빈 값
        request.setCustomerName("홍길동");

        // When & Then
        mockMvc.perform(post("/api/orders")
                .contentType(MediaType.APPLICATION_JSON)
                .content(objectMapper.writeValueAsString(request)))
                .andExpected(status().isBadRequest())
                .andExpect(jsonPath("$.success").value(false))
                .andExpect(jsonPath("$.errors").exists());
    }

    @Test
    void 주문_목록_조회_API_테스트() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/orders")
                .param("page", "0")
                .param("size", "10")
                .param("sortBy", "createdAt")
                .param("sortDir", "desc"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data").isArray())
                .andExpect(jsonPath("$.pagination").exists())
                .andExpect(jsonPath("$.pagination.currentPage").value(0))
                .andExpect(jsonPath("$.pagination.size").value(10));
    }

    @Test
    void 헬스체크_API_테스트() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/orders/health"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("UP"))
                .andExpect(jsonPath("$.service").value("Order Service"))
                .andExpect(jsonPath("$.timestamp").exists());
    }

    @Test
    void 주문_통계_API_테스트() throws Exception {
        // When & Then
        mockMvc.perform(get("/api/orders/statistics"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.data").isArray());
    }
}