from fastapi import Request, Response
from starlette.middleware.base import BaseHTTPMiddleware
import time
from collections import defaultdict
import threading

class MetricsMiddleware(BaseHTTPMiddleware):
    """메트릭 수집 미들웨어"""
    
    def __init__(self, app):
        super().__init__(app)
        self.request_count = defaultdict(int)
        self.request_duration = defaultdict(list)
        self.error_count = defaultdict(int)
        self.lock = threading.Lock()
    
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        
        # 요청 경로 정규화 (ID 파라미터 제거)
        path = request.url.path
        method = request.method
        
        # 동적 경로를 정적 경로로 변환 (예: /products/123 -> /products/{id})
        normalized_path = self._normalize_path(path)
        route_key = f"{method} {normalized_path}"
        
        try:
            response = await call_next(request)
            
            # 처리 시간 계산
            duration = time.time() - start_time
            
            # 메트릭 업데이트
            with self.lock:
                self.request_count[route_key] += 1
                self.request_duration[route_key].append(duration)
                
                # 에러 상태 코드 카운트
                if response.status_code >= 400:
                    error_key = f"{route_key}:{response.status_code}"
                    self.error_count[error_key] += 1
            
            return response
            
        except Exception as e:
            # 처리 시간 계산
            duration = time.time() - start_time
            
            # 에러 메트릭 업데이트
            with self.lock:
                self.request_count[route_key] += 1
                self.request_duration[route_key].append(duration)
                error_key = f"{route_key}:500"
                self.error_count[error_key] += 1
            
            raise
    
    def _normalize_path(self, path: str) -> str:
        """동적 경로를 정적 경로로 변환"""
        parts = path.split('/')
        normalized_parts = []
        
        for part in parts:
            if part == '':
                continue
            
            # UUID 패턴이나 숫자 패턴을 {id}로 변환
            if (len(part) == 36 and part.count('-') == 4) or part.isdigit():
                normalized_parts.append('{id}')
            else:
                normalized_parts.append(part)
        
        return '/' + '/'.join(normalized_parts) if normalized_parts else '/'
    
    def get_metrics(self) -> dict:
        """현재 메트릭 반환"""
        with self.lock:
            metrics = {
                'request_count': dict(self.request_count),
                'error_count': dict(self.error_count),
                'request_duration': {}
            }
            
            # 평균 응답 시간 계산
            for route, durations in self.request_duration.items():
                if durations:
                    metrics['request_duration'][route] = {
                        'avg': sum(durations) / len(durations),
                        'min': min(durations),
                        'max': max(durations),
                        'count': len(durations)
                    }
            
            return metrics
    
    def reset_metrics(self):
        """메트릭 초기화"""
        with self.lock:
            self.request_count.clear()
            self.request_duration.clear()
            self.error_count.clear()

# 전역 메트릭 인스턴스
metrics_middleware = None

def get_metrics_middleware():
    """메트릭 미들웨어 인스턴스 반환"""
    global metrics_middleware
    return metrics_middleware

def set_metrics_middleware(middleware):
    """메트릭 미들웨어 인스턴스 설정"""
    global metrics_middleware
    metrics_middleware = middleware