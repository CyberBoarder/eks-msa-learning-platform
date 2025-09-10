# Main Service (API Gateway)

EKS MSA 학습 플랫폼의 메인 API 게이트웨이 서비스입니다. 프론트엔드와 백엔드 마이크로서비스들 사이의 중간 계층 역할을 수행합니다.

## 주요 기능

### 🚀 API Gateway 기능
- **라우팅**: 프론트엔드 요청을 적절한 백엔드 서비스로 라우팅
- **프록시**: Catalog Service, Order Service로의 요청 프록시
- **파일 업로드**: S3를 통한 파일 업로드 및 관리

### 🔄 Circuit Breaker 패턴
- **장애 격리**: 백엔드 서비스 장애 시 Circuit Breaker를 통한 장애 전파 방지
- **Fallback**: 서비스 장애 시 목업 데이터 제공
- **자동 복구**: 서비스 복구 시 자동으로 Circuit Breaker 상태 변경

### 💾 Redis 캐싱
- **성능 최적화**: 자주 조회되는 데이터의 캐싱을 통한 응답 시간 단축
- **캐시 전략**: TTL 기반 캐시 만료 및 무효화
- **캐시 통계**: Redis 성능 메트릭 수집

### 🛡️ 보안 및 안정성
- **Rate Limiting**: IP 기반 요청 제한
- **CORS**: 프론트엔드 도메인 허용 설정
- **Helmet**: 보안 헤더 자동 설정
- **입력 검증**: 요청 데이터 검증 및 에러 처리

## API 엔드포인트

### 헬스체크
- `GET /health` - 기본 헬스체크
- `GET /health/detailed` - 상세 헬스체크 (모든 의존성 포함)
- `GET /health/live` - Kubernetes Liveness Probe
- `GET /health/ready` - Kubernetes Readiness Probe
- `GET /health/metrics` - Prometheus 메트릭

### 상품 카탈로그 (Catalog Service 프록시)
- `GET /api/catalog/products` - 상품 목록 조회
- `GET /api/catalog/products/:id` - 특정 상품 조회
- `GET /api/catalog/categories` - 카테고리 목록 조회
- `DELETE /api/catalog/cache` - 캐시 무효화 (관리자용)

### 주문 관리 (Order Service 프록시)
- `GET /api/orders` - 주문 목록 조회
- `GET /api/orders/:id` - 특정 주문 조회
- `POST /api/orders` - 새 주문 생성
- `PATCH /api/orders/:id/status` - 주문 상태 변경

### 파일 관리 (S3 연동)
- `POST /api/files/upload` - 파일 업로드
- `GET /api/files` - 파일 목록 조회
- `GET /api/files/:id/download` - 파일 다운로드 URL 생성
- `DELETE /api/files/:id` - 파일 삭제

### 관리자 기능
- `GET /api/admin/circuit-breakers` - 모든 Circuit Breaker 상태 조회
- `GET /api/admin/circuit-breakers/:serviceName` - 특정 Circuit Breaker 상태 조회
- `POST /api/admin/circuit-breakers/:serviceName/reset` - Circuit Breaker 리셋

## 환경 변수

```bash
# 서버 설정
PORT=3001
NODE_ENV=production

# 외부 서비스
CATALOG_SERVICE_URL=http://catalog-service:8000
ORDER_SERVICE_URL=http://order-service:8080
FRONTEND_URL=http://localhost:3000

# Redis 설정
REDIS_HOST=redis-cluster
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# AWS 설정
AWS_REGION=ap-northeast-2
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_BUCKET_NAME=eks-msa-learning-platform-files

# 파일 업로드 설정
MAX_FILE_SIZE=10485760
ALLOWED_FILE_TYPES=image/*,application/pdf,text/*

# Circuit Breaker 설정
CIRCUIT_BREAKER_TIMEOUT=10000
CIRCUIT_BREAKER_ERROR_THRESHOLD=50
CIRCUIT_BREAKER_RESET_TIMEOUT=30000
```

## 로컬 개발

### 1. 의존성 설치
```bash
npm install
```

### 2. 환경 변수 설정
```bash
cp .env.example .env
# .env 파일을 편집하여 필요한 값들을 설정
```

### 3. Redis 실행 (Docker)
```bash
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

### 4. 애플리케이션 실행
```bash
# 개발 모드
npm run dev

# 프로덕션 모드
npm start
```

### 5. 테스트 실행
```bash
# 단위 테스트
npm test

# 테스트 커버리지
npm run test:coverage

# 테스트 감시 모드
npm run test:watch
```

## Docker 빌드 및 실행

### 이미지 빌드
```bash
docker build -t main-service:latest .
```

### 컨테이너 실행
```bash
docker run -d \
  --name main-service \
  -p 3001:3001 \
  -e NODE_ENV=production \
  -e REDIS_HOST=redis \
  main-service:latest
```

## 모니터링

### 헬스체크
```bash
# 기본 헬스체크
curl http://localhost:3001/health

# 상세 헬스체크
curl http://localhost:3001/health/detailed

# Prometheus 메트릭
curl http://localhost:3001/health/metrics
```

### Circuit Breaker 상태 확인
```bash
# 모든 Circuit Breaker 상태
curl http://localhost:3001/api/admin/circuit-breakers

# 특정 서비스 Circuit Breaker 상태
curl http://localhost:3001/api/admin/circuit-breakers/catalog-service
```

## 아키텍처

```
Frontend (React) 
    ↓
Main Service (API Gateway)
    ↓
┌─────────────────┬─────────────────┐
│  Catalog Service │  Order Service  │
│  (Python/FastAPI)│  (Java/Spring)  │
└─────────────────┴─────────────────┘
    ↓                    ↓
┌─────────────────┬─────────────────┐
│   PostgreSQL    │     Redis       │
└─────────────────┴─────────────────┘
```

## 주요 특징

### Circuit Breaker 패턴
- **오픈 상태**: 연속된 실패 시 요청 차단
- **하프 오픈 상태**: 제한된 요청으로 서비스 상태 확인
- **클로즈 상태**: 정상 동작 시 모든 요청 허용

### 캐싱 전략
- **상품 데이터**: 5분 TTL
- **카테고리 데이터**: 30분 TTL (변경 빈도가 낮음)
- **주문 데이터**: 2분 TTL (실시간성 중요)

### 에러 처리
- **Graceful Degradation**: 백엔드 서비스 장애 시 목업 데이터 제공
- **상세한 에러 로깅**: 디버깅을 위한 포괄적인 에러 정보
- **사용자 친화적 에러 메시지**: 프론트엔드를 위한 명확한 에러 응답

## 성능 최적화

- **압축**: Gzip 압축을 통한 응답 크기 최소화
- **캐싱**: Redis를 통한 데이터 캐싱
- **Connection Pooling**: HTTP 클라이언트 연결 풀 사용
- **비동기 처리**: Node.js의 비동기 I/O 활용

## 보안

- **Rate Limiting**: DDoS 공격 방지
- **CORS**: 허용된 도메인에서만 접근 가능
- **Helmet**: 보안 헤더 자동 설정
- **입력 검증**: 모든 사용자 입력 검증
- **파일 업로드 제한**: 파일 타입 및 크기 제한