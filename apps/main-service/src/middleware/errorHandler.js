// 404 에러 핸들러
function notFoundHandler(req, res, next) {
  const error = new Error(`Not Found - ${req.originalUrl}`);
  error.status = 404;
  next(error);
}

// 전역 에러 핸들러
function errorHandler(err, req, res, next) {
  // 기본 상태 코드 설정
  let statusCode = err.status || err.statusCode || 500;
  
  // 특정 에러 타입에 따른 상태 코드 조정
  if (err.name === 'ValidationError') {
    statusCode = 400;
  } else if (err.name === 'UnauthorizedError') {
    statusCode = 401;
  } else if (err.name === 'ForbiddenError') {
    statusCode = 403;
  } else if (err.code === 'ECONNREFUSED') {
    statusCode = 503; // Service Unavailable
  } else if (err.code === 'ETIMEDOUT') {
    statusCode = 504; // Gateway Timeout
  }

  // 에러 로깅
  console.error('Error occurred:', {
    message: err.message,
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip,
    userAgent: req.get('User-Agent'),
    timestamp: new Date().toISOString()
  });

  // 개발 환경에서는 스택 트레이스 포함
  const isDevelopment = process.env.NODE_ENV === 'development';
  
  // 에러 응답 구성
  const errorResponse = {
    error: {
      message: err.message || 'Internal Server Error',
      status: statusCode,
      timestamp: new Date().toISOString(),
      path: req.originalUrl,
      method: req.method
    }
  };

  // 개발 환경에서만 스택 트레이스 추가
  if (isDevelopment) {
    errorResponse.error.stack = err.stack;
    errorResponse.error.details = err.details || null;
  }

  // 특정 에러 타입에 대한 추가 정보
  if (err.name === 'ValidationError') {
    errorResponse.error.validationErrors = err.errors || [];
  }

  // Circuit Breaker 에러 처리
  if (err.message && err.message.includes('Circuit breaker')) {
    errorResponse.error.type = 'CIRCUIT_BREAKER';
    errorResponse.error.message = 'Service temporarily unavailable. Please try again later.';
    errorResponse.error.retryAfter = 30; // 30초 후 재시도 권장
  }

  // Rate Limit 에러 처리
  if (err.message && err.message.includes('Too many requests')) {
    errorResponse.error.type = 'RATE_LIMIT';
    errorResponse.error.retryAfter = 900; // 15분 후 재시도 권장
  }

  // 파일 업로드 에러 처리
  if (err.code === 'LIMIT_FILE_SIZE') {
    errorResponse.error.type = 'FILE_TOO_LARGE';
    errorResponse.error.maxSize = process.env.MAX_FILE_SIZE || '10MB';
  }

  // 데이터베이스 연결 에러 처리
  if (err.code === 'ECONNREFUSED' && err.port) {
    errorResponse.error.type = 'DATABASE_CONNECTION';
    errorResponse.error.message = 'Database connection failed. Please try again later.';
  }

  // Redis 연결 에러 처리
  if (err.message && err.message.includes('Redis')) {
    errorResponse.error.type = 'CACHE_CONNECTION';
    errorResponse.error.message = 'Cache service unavailable. Functionality may be limited.';
  }

  // 외부 서비스 에러 처리
  if (err.response && err.response.status) {
    errorResponse.error.type = 'EXTERNAL_SERVICE';
    errorResponse.error.externalStatus = err.response.status;
    errorResponse.error.externalMessage = err.response.data?.message || 'External service error';
  }

  // 보안 관련 에러는 상세 정보 숨김
  if (statusCode === 401 || statusCode === 403) {
    errorResponse.error.message = statusCode === 401 ? 'Unauthorized' : 'Forbidden';
    delete errorResponse.error.stack;
    delete errorResponse.error.details;
  }

  // 헬스체크 관련 메트릭 업데이트 (실제 구현에서는 메트릭 수집 시스템 사용)
  if (statusCode >= 500) {
    // 서버 에러 카운터 증가
    console.log('Server error metric incremented');
  }

  res.status(statusCode).json(errorResponse);
}

// 비동기 에러 캐치 헬퍼
function asyncHandler(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

// 커스텀 에러 클래스들
class ValidationError extends Error {
  constructor(message, errors = []) {
    super(message);
    this.name = 'ValidationError';
    this.status = 400;
    this.errors = errors;
  }
}

class UnauthorizedError extends Error {
  constructor(message = 'Unauthorized') {
    super(message);
    this.name = 'UnauthorizedError';
    this.status = 401;
  }
}

class ForbiddenError extends Error {
  constructor(message = 'Forbidden') {
    super(message);
    this.name = 'ForbiddenError';
    this.status = 403;
  }
}

class NotFoundError extends Error {
  constructor(message = 'Not Found') {
    super(message);
    this.name = 'NotFoundError';
    this.status = 404;
  }
}

class ConflictError extends Error {
  constructor(message = 'Conflict') {
    super(message);
    this.name = 'ConflictError';
    this.status = 409;
  }
}

class ServiceUnavailableError extends Error {
  constructor(message = 'Service Unavailable') {
    super(message);
    this.name = 'ServiceUnavailableError';
    this.status = 503;
  }
}

module.exports = {
  notFoundHandler,
  errorHandler,
  asyncHandler,
  ValidationError,
  UnauthorizedError,
  ForbiddenError,
  NotFoundError,
  ConflictError,
  ServiceUnavailableError
};