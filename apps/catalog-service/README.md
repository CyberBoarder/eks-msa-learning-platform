# Catalog Service

EKS MSA 학습 플랫폼의 상품 카탈로그 관리 마이크로서비스입니다. Python FastAPI를 기반으로 구축되었으며, PostgreSQL과 Redis를 사용합니다.

## 주요 기능

### 🛍️ 상품 관리
- **CRUD 작업**: 상품 생성, 조회, 수정, 삭제
- **재고 관리**: 실시간 재고 추적 및 업데이트
- **가격 관리**: 정가, 원가, 세일가 관리
- **이미지 관리**: 상품 이미지 및 갤러리 이미지 URL 관리
- **SEO 최적화**: 메타 태그, slug, 태그 관리

### 📂 카테고리 관리
- **계층 구조**: 부모-자식 관계의 카테고리 트리
- **CRUD 작업**: 카테고리 생성, 조회, 수정, 삭제
- **정렬 및 활성화**: 카테고리 순서 및 활성화 상태 관리

### 🔍 검색 및 필터링
- **전문 검색**: 상품명, 설명, SKU 기반 검색
- **다중 필터**: 카테고리, 가격 범위, 재고 상태, 추천 상품 필터
- **정렬**: 이름, 가격, 생성일, 재고량 기준 정렬
- **페이지네이션**: 효율적인 대용량 데이터 처리

### ⚡ 성능 최적화
- **Redis 캐싱**: 자주 조회되는 데이터의 캐싱
- **비동기 처리**: FastAPI의 비동기 I/O 활용
- **데이터베이스 최적화**: 인덱스 및 쿼리 최적화
- **연결 풀링**: PostgreSQL 연결 풀 관리

## API 엔드포인트

### 헬스체크
- `GET /health/` - 기본 헬스체크
- `GET /health/detailed` - 상세 헬스체크 (DB, Redis 상태 포함)
- `GET /health/live` - Kubernetes Liveness Probe
- `GET /health/ready` - Kubernetes Readiness Probe
- `GET /health/metrics` - Prometheus 메트릭

### 상품 관리
- `GET /products/` - 상품 목록 조회 (페이지네이션, 검색, 필터링)
- `GET /products/{product_id}` - 특정 상품 상세 조회
- `POST /products/` - 새 상품 생성
- `PUT /products/{product_id}` - 상품 정보 업데이트
- `DELETE /products/{product_id}` - 상품 삭제
- `PATCH /products/{product_id}/stock` - 상품 재고 업데이트
- `GET /products/category/{category_id}` - 카테고리별 상품 조회

### 카테고리 관리
- `GET /categories/` - 카테고리 목록 조회
- `GET /categories/tree` - 계층 구조 카테고리 트리 조회
- `GET /categories/{category_id}` - 특정 카테고리 조회
- `POST /categories/` - 새 카테고리 생성
- `PUT /categories/{category_id}` - 카테고리 정보 업데이트
- `DELETE /categories/{category_id}` - 카테고리 삭제

## 데이터 모델

### Category (카테고리)
```python
{
    "id": "electronics",
    "name": "전자제품",
    "description": "컴퓨터 및 전자기기",
    "parent_id": null,
    "is_active": true,
    "sort_order": 0,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
}
```

### Product (상품)
```python
{
    "id": "laptop-001",
    "name": "고성능 노트북",
    "description": "개발자를 위한 고성능 노트북",
    "short_description": "16GB RAM, 512GB SSD",
    "sku": "LAPTOP-001",
    "category_id": "electronics",
    "price": 1500000.00,
    "sale_price": 1350000.00,
    "stock_quantity": 10,
    "is_active": true,
    "is_featured": true,
    "image_url": "https://example.com/laptop.jpg",
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
}
```

## 환경 변수

```bash
# 애플리케이션 설정
ENVIRONMENT=production
DEBUG=false

# 데이터베이스 설정
DATABASE_URL=postgresql+asyncpg://catalog_user:catalog_pass@postgres:5432/catalog_db
DATABASE_POOL_SIZE=10
DATABASE_MAX_OVERFLOW=20

# Redis 설정
REDIS_URL=redis://redis-cluster:6379/0
REDIS_PASSWORD=
REDIS_MAX_CONNECTIONS=10

# 캐시 TTL 설정 (초)
CACHE_TTL_PRODUCTS=300
CACHE_TTL_CATEGORIES=1800
CACHE_TTL_PRODUCT_DETAIL=600

# CORS 설정
ALLOWED_ORIGINS=["http://frontend-service", "http://main-service"]

# AWS 설정
AWS_REGION=ap-northeast-2
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
S3_BUCKET_NAME=eks-msa-catalog-images
```

## 로컬 개발

### 1. 의존성 설치
```bash
pip install -r requirements.txt
```

### 2. 환경 변수 설정
```bash
cp .env.example .env
# .env 파일을 편집하여 필요한 값들을 설정
```

### 3. 데이터베이스 설정
```bash
# PostgreSQL 실행 (Docker)
docker run -d \
  --name postgres \
  -e POSTGRES_USER=catalog_user \
  -e POSTGRES_PASSWORD=catalog_pass \
  -e POSTGRES_DB=catalog_db \
  -p 5432:5432 \
  postgres:15

# 마이그레이션 실행
alembic upgrade head
```

### 4. Redis 실행
```bash
docker run -d --name redis -p 6379:6379 redis:7-alpine
```

### 5. 애플리케이션 실행
```bash
# 개발 모드
uvicorn src.main:app --reload --host 0.0.0.0 --port 8000

# 프로덕션 모드
python -m uvicorn src.main:app --host 0.0.0.0 --port 8000
```

### 6. 테스트 실행
```bash
# 단위 테스트
pytest src/tests/

# 커버리지 포함 테스트
pytest --cov=src src/tests/

# 특정 테스트 파일
pytest src/tests/test_health.py -v
```

## Docker 빌드 및 실행

### 이미지 빌드
```bash
docker build -t catalog-service:latest .
```

### 컨테이너 실행
```bash
docker run -d \
  --name catalog-service \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://catalog_user:catalog_pass@postgres:5432/catalog_db \
  -e REDIS_URL=redis://redis:6379/0 \
  catalog-service:latest
```

## 데이터베이스 마이그레이션

### 새 마이그레이션 생성
```bash
alembic revision --autogenerate -m "Add new field to product"
```

### 마이그레이션 적용
```bash
alembic upgrade head
```

### 마이그레이션 롤백
```bash
alembic downgrade -1
```

## API 문서

개발 환경에서는 다음 URL에서 API 문서를 확인할 수 있습니다:
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## 모니터링

### 헬스체크
```bash
# 기본 헬스체크
curl http://localhost:8000/health/

# 상세 헬스체크
curl http://localhost:8000/health/detailed

# Prometheus 메트릭
curl http://localhost:8000/health/metrics
```

### 로그 확인
```bash
# 컨테이너 로그
docker logs catalog-service

# 실시간 로그
docker logs -f catalog-service
```

## 성능 최적화

### 캐싱 전략
- **상품 목록**: 5분 TTL (자주 변경됨)
- **카테고리 목록**: 30분 TTL (변경 빈도 낮음)
- **상품 상세**: 10분 TTL (중간 빈도)

### 데이터베이스 최적화
- **인덱스**: 검색 및 필터링에 사용되는 컬럼들에 인덱스 적용
- **연결 풀**: 적절한 연결 풀 크기 설정
- **쿼리 최적화**: N+1 문제 방지를 위한 eager loading 사용

### 비동기 처리
- **FastAPI**: 비동기 엔드포인트 사용
- **SQLAlchemy**: 비동기 ORM 사용
- **Redis**: 비동기 Redis 클라이언트 사용

## 보안

### 입력 검증
- **Pydantic**: 모든 입력 데이터 검증
- **SQL Injection**: ORM 사용으로 방지
- **XSS**: 출력 데이터 이스케이프

### 인증 및 권한
- **JWT**: 토큰 기반 인증 (Main Service에서 처리)
- **RBAC**: 역할 기반 접근 제어
- **CORS**: 허용된 도메인에서만 접근 가능

## 아키텍처

```
┌─────────────────┐    ┌─────────────────┐
│   Main Service  │────│ Catalog Service │
│  (API Gateway)  │    │   (FastAPI)     │
└─────────────────┘    └─────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
            ┌───────▼────────┐  ┌───────▼────────┐
            │   PostgreSQL   │  │     Redis      │
            │   (Database)   │  │    (Cache)     │
            └────────────────┘  └────────────────┘
```

## 트러블슈팅

### 일반적인 문제들

1. **데이터베이스 연결 실패**
   ```bash
   # 연결 상태 확인
   curl http://localhost:8000/health/ready
   
   # 데이터베이스 로그 확인
   docker logs postgres
   ```

2. **Redis 연결 실패**
   ```bash
   # Redis 상태 확인
   docker exec redis redis-cli ping
   
   # Redis 로그 확인
   docker logs redis
   ```

3. **마이그레이션 오류**
   ```bash
   # 현재 마이그레이션 상태 확인
   alembic current
   
   # 마이그레이션 히스토리 확인
   alembic history
   ```

4. **캐시 문제**
   ```bash
   # Redis 캐시 초기화
   docker exec redis redis-cli FLUSHDB
   ```

## 기여하기

1. 이슈 생성 또는 기존 이슈 확인
2. 기능 브랜치 생성 (`git checkout -b feature/amazing-feature`)
3. 변경사항 커밋 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시 (`git push origin feature/amazing-feature`)
5. Pull Request 생성