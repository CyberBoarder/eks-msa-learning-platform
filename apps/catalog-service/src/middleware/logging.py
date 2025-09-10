from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import time
import logging
import uuid

logger = logging.getLogger(__name__)

class LoggingMiddleware(BaseHTTPMiddleware):
    """요청/응답 로깅 미들웨어"""
    
    async def dispatch(self, request: Request, call_next):
        # 요청 ID 생성
        request_id = str(uuid.uuid4())[:8]
        
        # 요청 시작 시간
        start_time = time.time()
        
        # 요청 정보 로깅
        logger.info(
            f"Request {request_id}: {request.method} {request.url.path} "
            f"from {request.client.host if request.client else 'unknown'}"
        )
        
        # 요청 헤더 로깅 (민감한 정보 제외)
        safe_headers = {}
        for name, value in request.headers.items():
            if name.lower() not in ['authorization', 'cookie', 'x-api-key']:
                safe_headers[name] = value
        
        logger.debug(f"Request {request_id} headers: {safe_headers}")
        
        # 요청 처리
        try:
            response = await call_next(request)
            
            # 처리 시간 계산
            process_time = time.time() - start_time
            
            # 응답 정보 로깅
            logger.info(
                f"Response {request_id}: {response.status_code} "
                f"in {process_time:.4f}s"
            )
            
            # 응답 헤더에 요청 ID 추가
            response.headers["X-Request-ID"] = request_id
            response.headers["X-Process-Time"] = str(process_time)
            
            return response
            
        except Exception as e:
            # 에러 처리 시간 계산
            process_time = time.time() - start_time
            
            # 에러 로깅
            logger.error(
                f"Error {request_id}: {str(e)} "
                f"in {process_time:.4f}s"
            )
            
            raise