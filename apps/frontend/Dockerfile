# Multi-stage build for React frontend
FROM node:18-alpine AS builder

# 작업 디렉토리 설정
WORKDIR /app

# package.json과 package-lock.json 복사
COPY package*.json ./

# 의존성 설치
RUN npm ci --only=production

# 소스 코드 복사
COPY . .

# 프로덕션 빌드
RUN npm run build

# Production stage with nginx
FROM nginx:1.25-alpine

# nginx 설정 파일 복사
COPY nginx.conf /etc/nginx/nginx.conf

# 빌드된 정적 파일 복사
COPY --from=builder /app/build /usr/share/nginx/html

# 헬스체크 스크립트 추가
RUN apk add --no-cache curl

# 포트 노출
EXPOSE 80

# 헬스체크 설정
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# nginx 실행
CMD ["nginx", "-g", "daemon off;"]