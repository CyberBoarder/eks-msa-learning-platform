import redis.asyncio as redis
import json
import logging
from typing import Any, Optional
from datetime import timedelta

from .config import settings

logger = logging.getLogger(__name__)

# Redis 클라이언트 생성
redis_client = redis.from_url(
    settings.REDIS_URL,
    password=settings.REDIS_PASSWORD if settings.REDIS_PASSWORD else None,
    max_connections=settings.REDIS_MAX_CONNECTIONS,
    decode_responses=True,
    retry_on_timeout=True,
    socket_keepalive=True,
    socket_keepalive_options={},
)

class CacheManager:
    """캐시 관리 클래스"""
    
    def __init__(self, redis_client: redis.Redis):
        self.redis = redis_client
    
    async def get(self, key: str) -> Optional[Any]:
        """캐시에서 데이터 조회"""
        try:
            data = await self.redis.get(key)
            if data:
                return json.loads(data)
            return None
        except Exception as e:
            logger.error(f"Cache get error for key {key}: {e}")
            return None
    
    async def set(self, key: str, value: Any, ttl: int = 300) -> bool:
        """캐시에 데이터 저장"""
        try:
            serialized_value = json.dumps(value, default=str)
            await self.redis.setex(key, ttl, serialized_value)
            return True
        except Exception as e:
            logger.error(f"Cache set error for key {key}: {e}")
            return False
    
    async def delete(self, key: str) -> bool:
        """캐시에서 데이터 삭제"""
        try:
            await self.redis.delete(key)
            return True
        except Exception as e:
            logger.error(f"Cache delete error for key {key}: {e}")
            return False
    
    async def delete_pattern(self, pattern: str) -> int:
        """패턴에 맞는 키들 삭제"""
        try:
            keys = await self.redis.keys(pattern)
            if keys:
                deleted = await self.redis.delete(*keys)
                return deleted
            return 0
        except Exception as e:
            logger.error(f"Cache delete pattern error for pattern {pattern}: {e}")
            return 0
    
    async def exists(self, key: str) -> bool:
        """키 존재 여부 확인"""
        try:
            return await self.redis.exists(key) > 0
        except Exception as e:
            logger.error(f"Cache exists error for key {key}: {e}")
            return False
    
    async def ttl(self, key: str) -> int:
        """키의 TTL 조회"""
        try:
            return await self.redis.ttl(key)
        except Exception as e:
            logger.error(f"Cache TTL error for key {key}: {e}")
            return -1
    
    async def increment(self, key: str, amount: int = 1) -> int:
        """카운터 증가"""
        try:
            return await self.redis.incrby(key, amount)
        except Exception as e:
            logger.error(f"Cache increment error for key {key}: {e}")
            return 0
    
    async def get_stats(self) -> dict:
        """Redis 통계 정보 조회"""
        try:
            info = await self.redis.info()
            return {
                "connected_clients": info.get("connected_clients", 0),
                "used_memory": info.get("used_memory", 0),
                "used_memory_human": info.get("used_memory_human", "0B"),
                "keyspace_hits": info.get("keyspace_hits", 0),
                "keyspace_misses": info.get("keyspace_misses", 0),
                "total_commands_processed": info.get("total_commands_processed", 0),
                "uptime_in_seconds": info.get("uptime_in_seconds", 0),
            }
        except Exception as e:
            logger.error(f"Cache stats error: {e}")
            return {}
    
    async def ping(self) -> bool:
        """Redis 연결 상태 확인"""
        try:
            await self.redis.ping()
            return True
        except Exception as e:
            logger.error(f"Cache ping error: {e}")
            return False

# 전역 캐시 매니저 인스턴스
cache_manager = CacheManager(redis_client)

# 캐시 키 생성 헬퍼 함수들
def get_product_cache_key(product_id: str) -> str:
    """상품 캐시 키 생성"""
    return f"product:{product_id}"

def get_products_list_cache_key(
    category_id: Optional[str] = None,
    search: Optional[str] = None,
    page: int = 1,
    size: int = 20,
    **filters
) -> str:
    """상품 목록 캐시 키 생성"""
    key_parts = ["products"]
    
    if category_id:
        key_parts.append(f"cat:{category_id}")
    
    if search:
        key_parts.append(f"search:{search}")
    
    key_parts.append(f"page:{page}")
    key_parts.append(f"size:{size}")
    
    # 추가 필터들
    for key, value in filters.items():
        if value is not None:
            key_parts.append(f"{key}:{value}")
    
    return ":".join(key_parts)

def get_category_cache_key(category_id: str) -> str:
    """카테고리 캐시 키 생성"""
    return f"category:{category_id}"

def get_categories_list_cache_key() -> str:
    """카테고리 목록 캐시 키 생성"""
    return "categories:all"

def get_category_products_cache_key(category_id: str, page: int = 1, size: int = 20) -> str:
    """카테고리별 상품 목록 캐시 키 생성"""
    return f"category:{category_id}:products:page:{page}:size:{size}"

# 캐시 데코레이터
def cache_result(key_func, ttl: int = 300):
    """결과를 캐시하는 데코레이터"""
    def decorator(func):
        async def wrapper(*args, **kwargs):
            # 캐시 키 생성
            cache_key = key_func(*args, **kwargs)
            
            # 캐시에서 조회
            cached_result = await cache_manager.get(cache_key)
            if cached_result is not None:
                logger.debug(f"Cache hit for key: {cache_key}")
                return cached_result
            
            # 캐시 미스 시 함수 실행
            result = await func(*args, **kwargs)
            
            # 결과를 캐시에 저장
            await cache_manager.set(cache_key, result, ttl)
            logger.debug(f"Cache set for key: {cache_key}")
            
            return result
        return wrapper
    return decorator