package com.eksmsa.learning.orderservice.exception;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.context.request.WebRequest;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger logger = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /**
     * 유효성 검증 실패 예외 처리
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Map<String, Object>> handleValidationExceptions(
            MethodArgumentNotValidException ex, WebRequest request) {
        
        logger.warn("유효성 검증 실패: {}", ex.getMessage());

        Map<String, String> fieldErrors = new HashMap<>();
        ex.getBindingResult().getAllErrors().forEach((error) -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            fieldErrors.put(fieldName, errorMessage);
        });

        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("message", "입력 데이터 유효성 검증에 실패했습니다");
        response.put("errors", fieldErrors);
        response.put("timestamp", LocalDateTime.now());
        response.put("path", request.getDescription(false));

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    /**
     * IllegalArgumentException 처리
     */
    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleIllegalArgumentException(
            IllegalArgumentException ex, WebRequest request) {
        
        logger.warn("잘못된 인수: {}", ex.getMessage());

        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("message", ex.getMessage());
        response.put("error", "INVALID_ARGUMENT");
        response.put("timestamp", LocalDateTime.now());
        response.put("path", request.getDescription(false));

        return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(response);
    }

    /**
     * RuntimeException 처리
     */
    @ExceptionHandler(RuntimeException.class)
    public ResponseEntity<Map<String, Object>> handleRuntimeException(
            RuntimeException ex, WebRequest request) {
        
        logger.error("런타임 예외 발생: {}", ex.getMessage(), ex);

        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("message", ex.getMessage());
        response.put("error", "RUNTIME_ERROR");
        response.put("timestamp", LocalDateTime.now());
        response.put("path", request.getDescription(false));

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }

    /**
     * 일반 예외 처리
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<Map<String, Object>> handleGenericException(
            Exception ex, WebRequest request) {
        
        logger.error("예상치 못한 예외 발생: {}", ex.getMessage(), ex);

        Map<String, Object> response = new HashMap<>();
        response.put("success", false);
        response.put("message", "서버 내부 오류가 발생했습니다");
        response.put("error", "INTERNAL_SERVER_ERROR");
        response.put("timestamp", LocalDateTime.now());
        response.put("path", request.getDescription(false));

        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(response);
    }
}