from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import NullPool
import logging

from .config import settings

logger = logging.getLogger(__name__)

# 데이터베이스 엔진 생성
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=settings.DATABASE_POOL_SIZE,
    max_overflow=settings.DATABASE_MAX_OVERFLOW,
    poolclass=NullPool if settings.ENVIRONMENT == "test" else None,
    future=True
)

# 세션 팩토리 생성
AsyncSessionLocal = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False
)

# Base 클래스 정의
class Base(DeclarativeBase):
    pass

# 데이터베이스 세션 의존성
async def get_db() -> AsyncSession:
    """데이터베이스 세션을 제공하는 의존성"""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception as e:
            logger.error(f"Database session error: {e}")
            await session.rollback()
            raise
        finally:
            await session.close()

# 데이터베이스 연결 테스트
async def test_database_connection():
    """데이터베이스 연결 테스트"""
    try:
        async with engine.begin() as conn:
            await conn.execute("SELECT 1")
        logger.info("Database connection successful")
        return True
    except Exception as e:
        logger.error(f"Database connection failed: {e}")
        return False