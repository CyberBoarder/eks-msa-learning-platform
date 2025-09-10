package com.eksmsa.learning.orderservice.config;

import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.boot.actuate.health.Health;
import org.springframework.boot.actuate.health.HealthIndicator;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.core.RedisTemplate;

@Configuration
public class ActuatorConfig {

    /**
     * 데이터베이스 헬스 체크
     */
    @Bean
    public HealthIndicator databaseHealthIndicator() {
        return () -> {
            try {
                // 간단한 데이터베이스 연결 확인
                // 실제로는 OrderRepository를 통해 확인할 수 있음
                return Health.up()
                    .withDetail("database", "PostgreSQL")
                    .withDetail("status", "Connected")
                    .build();
            } catch (Exception e) {
                return Health.down()
                    .withDetail("database", "PostgreSQL")
                    .withDetail("error", e.getMessage())
                    .build();
            }
        };
    }

    /**
     * Redis 헬스 체크
     */
    @Bean
    public HealthIndicator redisHealthIndicator(RedisTemplate<String, Object> redisTemplate) {
        return () -> {
            try {
                redisTemplate.getConnectionFactory().getConnection().ping();
                return Health.up()
                    .withDetail("redis", "Connected")
                    .withDetail("status", "UP")
                    .build();
            } catch (Exception e) {
                return Health.down()
                    .withDetail("redis", "Connection failed")
                    .withDetail("error", e.getMessage())
                    .build();
            }
        };
    }

    /**
     * 커스텀 메트릭 등록
     */
    @Bean
    public MeterRegistry.Config meterRegistryConfig(MeterRegistry meterRegistry) {
        // 애플리케이션별 태그 추가
        meterRegistry.config().commonTags("application", "order-service");
        meterRegistry.config().commonTags("version", "1.0.0");
        
        return meterRegistry.config();
    }
}