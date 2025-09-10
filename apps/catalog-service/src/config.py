from pydantic_settings import BaseSettings
from typing import List
import os

class Settings(BaseSettings):
    """애플리케이션 설정"""
    
    # 기본 설정
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    
    # 데이터베이스 설정
    DATABASE_URL: str = "postgresql+asyncpg://catalog_user:catalog_pass@localhost:5432/catalog_db"
    DATABASE_POOL_SIZE: int = 10
    DATABASE_MAX_OVERFLOW: int = 20
    
    # Redis 설정
    REDIS_URL: str = "redis://localhost:6379/0"
    REDIS_PASSWORD: str = ""
    REDIS_MAX_CONNECTIONS: int = 10
    
    # 캐시 설정
    CACHE_TTL_PRODUCTS: int = 300  # 5분
    CACHE_TTL_CATEGORIES: int = 1800  # 30분
    CACHE_TTL_PRODUCT_DETAIL: int = 600  # 10분
    
    # CORS 설정
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:3001",
        "http://frontend-service",
        "http://main-service"
    ]
    
    # 페이지네이션 설정
    DEFAULT_PAGE_SIZE: int = 20
    MAX_PAGE_SIZE: int = 100
    
    # 로깅 설정
    LOG_LEVEL: str = "INFO"
    LOG_FORMAT: str = "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    
    # 메트릭 설정
    METRICS_ENABLED: bool = True
    METRICS_PORT: int = 9090
    
    # AWS 설정 (이미지 업로드용)
    AWS_REGION: str = "ap-northeast-2"
    AWS_ACCESS_KEY_ID: str = ""
    AWS_SECRET_ACCESS_KEY: str = ""
    S3_BUCKET_NAME: str = "eks-msa-catalog-images"
    
    class Config:
        env_file = ".env"
        case_sensitive = True

# 전역 설정 인스턴스
settings = Settings()

# 환경별 설정 오버라이드
if settings.ENVIRONMENT == "production":
    settings.DEBUG = False
    settings.LOG_LEVEL = "WARNING"
elif settings.ENVIRONMENT == "development":
    settings.DEBUG = True
    settings.LOG_LEVEL = "DEBUG"
elif settings.ENVIRONMENT == "test":
    settings.DATABASE_URL = "postgresql+asyncpg://test_user:test_pass@localhost:5432/test_catalog_db"
    settings.REDIS_URL = "redis://localhost:6379/1"