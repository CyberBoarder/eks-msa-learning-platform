# Multi-stage build for Python FastAPI Catalog Service
FROM python:3.11-slim AS builder

# 시스템 의존성 설치
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 작업 디렉토리 설정
WORKDIR /app

# Python 의존성 파일 복사
COPY requirements.txt .

# Python 의존성 설치
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Production stage
FROM python:3.11-slim AS production

# 시스템 의존성 설치 (런타임 필요한 것들만)
RUN apt-get update && apt-get install -y \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 보안을 위한 non-root 사용자 생성
RUN groupadd -r appuser && useradd -r -g appuser appuser

# 작업 디렉토리 설정
WORKDIR /app

# 빌드 단계에서 설치된 Python 패키지 복사
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# 애플리케이션 소스 코드 복사
COPY src/ ./src/
COPY alembic.ini ./
COPY alembic/ ./alembic/

# 소유권 변경
RUN chown -R appuser:appuser /app

# 사용자 변경
USER appuser

# 포트 노출
EXPOSE 8000

# 헬스체크 설정
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1

# 환경 변수 설정
ENV PYTHONPATH=/app
ENV PYTHONUNBUFFERED=1

# 애플리케이션 실행
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]