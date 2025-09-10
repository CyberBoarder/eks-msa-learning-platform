from fastapi import FastAPI, HTTPException, Depends, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from contextlib import asynccontextmanager
import uvicorn
import os
from typing import List, Optional
import logging

from .database import engine, get_db
from .models import Base
from .routers import products, categories, health
from .config import settings
from .cache import redis_client
from .middleware.logging import LoggingMiddleware
from .middleware.metrics import MetricsMiddleware, set_metrics_middleware

# 로깅 설정
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@asynccontextmanager
async def lifespan(app: FastAPI):
    """애플리케이션 생명주기 관리"""
    # 시작 시 실행
    logger.info("Starting Catalog Service...")
    
    # 데이터베이스 테이블 생성
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    
    # Redis 연결 확인
    try:
        await redis_client.ping()
        logger.info("Redis connection established")
    except Exception as e:
        logger.warning(f"Redis connection failed: {e}")
    
    logger.info("Catalog Service started successfully")
    
    yield
    
    # 종료 시 실행
    logger.info("Shutting down Catalog Service...")
    await redis_client.close()
    await engine.dispose()
    logger.info("Catalog Service shutdown complete")

# FastAPI 애플리케이션 생성
app = FastAPI(
    title="Catalog Service",
    description="상품 카탈로그 관리를 위한 마이크로서비스",
    version="1.0.0",
    docs_url="/docs" if settings.ENVIRONMENT == "development" else None,
    redoc_url="/redoc" if settings.ENVIRONMENT == "development" else None,
    lifespan=lifespan
)

# 미들웨어 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1000)
app.add_middleware(LoggingMiddleware)

# 메트릭 미들웨어 추가 및 전역 설정
metrics_middleware = MetricsMiddleware(app)
app.add_middleware(MetricsMiddleware)
set_metrics_middleware(metrics_middleware)

# 라우터 등록
app.include_router(health.router, prefix="/health", tags=["health"])
app.include_router(products.router, prefix="/products", tags=["products"])
app.include_router(categories.router, prefix="/categories", tags=["categories"])

@app.get("/")
async def root():
    """루트 엔드포인트"""
    return {
        "service": "Catalog Service",
        "version": "1.0.0",
        "status": "running",
        "environment": settings.ENVIRONMENT,
        "docs_url": "/docs" if settings.ENVIRONMENT == "development" else None
    }

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.ENVIRONMENT == "development",
        log_level="info"
    )