# Multi-stage build for Order Service
FROM openjdk:17-jdk-slim as builder

# 작업 디렉토리 설정
WORKDIR /app

# Maven Wrapper와 pom.xml 복사
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .

# 의존성 다운로드 (캐시 최적화)
RUN ./mvnw dependency:go-offline -B

# 소스 코드 복사
COPY src src

# 애플리케이션 빌드
RUN ./mvnw clean package -DskipTests

# Runtime stage
FROM openjdk:17-jre-slim

# 보안을 위한 non-root 사용자 생성
RUN groupadd -r orderservice && useradd -r -g orderservice orderservice

# 작업 디렉토리 설정
WORKDIR /app

# 필요한 패키지 설치
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 빌드된 JAR 파일 복사
COPY --from=builder /app/target/*.jar app.jar

# 애플리케이션 소유권 변경
RUN chown -R orderservice:orderservice /app

# non-root 사용자로 전환
USER orderservice

# 포트 노출
EXPOSE 8080

# 헬스체크 설정
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# JVM 옵션 설정
ENV JAVA_OPTS="-Xmx512m -Xms256m -XX:+UseG1GC -XX:+UseContainerSupport"

# 애플리케이션 실행
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]