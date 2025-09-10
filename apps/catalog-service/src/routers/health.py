from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime
import logging

from ..database import get_db, test_database_connection
from ..cache import cache_manager
from ..schemas import HealthResponse, DetailedHealthResponse
from ..config import settings

router = APIRouter()
logger = logging.getLogger(__name__)

@router.get("/", response_model=HealthResponse)
async def health_check():
    """기본 헬스체크"""
    return HealthResponse(
        service="Catalog Service",
        status="healthy",
        timestamp=datetime.utcnow(),
        version="1.0.0",
        environment=settings.ENVIRONMENT
    )

@router.get("/detailed", response_model=DetailedHealthResponse)
async def detailed_health_check(db: AsyncSession = Depends(get_db)):
    """상세 헬스체크"""
    
    # 데이터베이스 연결 확인
    db_healthy = await test_database_connection()
    db_status = {
        "status": "connected" if db_healthy else "disconnected",
        "url": settings.DATABASE_URL.split("@")[-1] if "@" in settings.DATABASE_URL else "unknown"
    }
    
    # Redis 연결 확인
    cache_healthy = await cache_manager.ping()
    cache_stats = await cache_manager.get_stats() if cache_healthy else {}
    cache_status = {
        "status": "connected" if cache_healthy else "disconnected",
        "stats": cache_stats
    }
    
    # 의존성 서비스 상태 (실제로는 다른 서비스들과의 연결 확인)
    dependencies = {
        "main_service": {
            "status": "unknown",
            "description": "Main API Gateway Service"
        }
    }
    
    return DetailedHealthResponse(
        service="Catalog Service",
        status="healthy" if db_healthy and cache_healthy else "degraded",
        timestamp=datetime.utcnow(),
        version="1.0.0",
        environment=settings.ENVIRONMENT,
        database=db_status,
        cache=cache_status,
        dependencies=dependencies
    )

@router.get("/live")
async def liveness_probe():
    """Kubernetes Liveness Probe"""
    return {"status": "alive"}

@router.get("/ready")
async def readiness_probe(db: AsyncSession = Depends(get_db)):
    """Kubernetes Readiness Probe"""
    
    # 데이터베이스 연결 확인
    db_healthy = await test_database_connection()
    
    # Redis 연결 확인
    cache_healthy = await cache_manager.ping()
    
    if db_healthy and cache_healthy:
        return {"status": "ready"}
    else:
        from fastapi import HTTPException
        raise HTTPException(status_code=503, detail="Service not ready")

@router.get("/metrics")
async def metrics():
    """Prometheus 메트릭"""
    
    # 캐시 통계
    cache_stats = await cache_manager.get_stats()
    
    # 기본 메트릭들
    metrics_data = f"""
# HELP catalog_service_uptime_seconds Total uptime of the service in seconds
# TYPE catalog_service_uptime_seconds counter
catalog_service_uptime_seconds {cache_stats.get('uptime_in_seconds', 0)}

# HELP catalog_service_cache_hits_total Total number of cache hits
# TYPE catalog_service_cache_hits_total counter
catalog_service_cache_hits_total {cache_stats.get('keyspace_hits', 0)}

# HELP catalog_service_cache_misses_total Total number of cache misses
# TYPE catalog_service_cache_misses_total counter
catalog_service_cache_misses_total {cache_stats.get('keyspace_misses', 0)}

# HELP catalog_service_cache_memory_usage_bytes Cache memory usage in bytes
# TYPE catalog_service_cache_memory_usage_bytes gauge
catalog_service_cache_memory_usage_bytes {cache_stats.get('used_memory', 0)}

# HELP catalog_service_cache_connected_clients Number of connected cache clients
# TYPE catalog_service_cache_connected_clients gauge
catalog_service_cache_connected_clients {cache_stats.get('connected_clients', 0)}

# HELP catalog_service_commands_processed_total Total number of commands processed
# TYPE catalog_service_commands_processed_total counter
catalog_service_commands_processed_total {cache_stats.get('total_commands_processed', 0)}
    """.strip()
    
    from fastapi import Response
    return Response(content=metrics_data, media_type="text/plain")