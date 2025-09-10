# Multi-stage build for Node.js Main Service
FROM node:18-alpine AS builder

# 작업 디렉토리 설정
WORKDIR /app

# package.json과 package-lock.json 복사
COPY package*.json ./

# 의존성 설치 (개발 의존성 제외)
RUN npm ci --only=production && npm cache clean --force

# 소스 코드 복사
COPY . .

# Production stage
FROM node:18-alpine AS production

# 보안을 위한 non-root 사용자 생성
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# 작업 디렉토리 설정
WORKDIR /app

# 필요한 시스템 패키지 설치
RUN apk add --no-cache \
    curl \
    dumb-init

# 빌드 단계에서 의존성과 소스 코드 복사
COPY --from=builder --chown=nodejs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nodejs:nodejs /app/src ./src
COPY --from=builder --chown=nodejs:nodejs /app/package*.json ./

# 사용자 변경
USER nodejs

# 포트 노출
EXPOSE 3001

# 헬스체크 설정
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/health || exit 1

# dumb-init을 사용하여 시그널 처리 개선
ENTRYPOINT ["dumb-init", "--"]

# 애플리케이션 실행
CMD ["node", "src/index.js"]