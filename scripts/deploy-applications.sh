#!/bin/bash

# EKS MSA Learning Platform - Application Deployment Script
# 모든 마이크로서비스를 순차적으로 배포하는 스크립트

set -euo pipefail

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로깅 함수
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 환경 변수 확인
check_prerequisites() {
    log_info "전제 조건 확인 중..."
    
    # kubectl 설치 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # 클러스터 연결 확인
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Kubernetes 클러스터에 연결할 수 없습니다."
        exit 1
    fi
    
    # 필수 환경 변수 확인
    if [[ -z "${ECR_REGISTRY:-}" ]]; then
        log_error "ECR_REGISTRY 환경 변수가 설정되지 않았습니다."
        exit 1
    fi
    
    if [[ -z "${AWS_ACCOUNT_ID:-}" ]]; then
        log_error "AWS_ACCOUNT_ID 환경 변수가 설정되지 않았습니다."
        exit 1
    fi
    
    log_success "전제 조건 확인 완료"
}

# 네임스페이스 생성
create_namespaces() {
    log_info "네임스페이스 생성 중..."
    
    kubectl apply -f k8s/namespaces/namespaces.yaml
    
    # 네임스페이스 생성 대기
    kubectl wait --for=condition=Active namespace/frontend --timeout=60s
    kubectl wait --for=condition=Active namespace/backend --timeout=60s
    
    log_success "네임스페이스 생성 완료"
}

# ConfigMap 및 Secret 배포
deploy_configs() {
    log_info "ConfigMap 및 Secret 배포 중..."
    
    # ConfigMap 배포
    kubectl apply -f k8s/config/configmaps.yaml
    
    # Secret 배포 (이미 존재한다고 가정)
    if kubectl get secret -n backend catalog-db-secret &> /dev/null; then
        log_success "데이터베이스 Secret이 이미 존재합니다."
    else
        log_warning "데이터베이스 Secret이 존재하지 않습니다. 수동으로 생성해주세요."
    fi
    
    if kubectl get secret -n backend redis-secret &> /dev/null; then
        log_success "Redis Secret이 이미 존재합니다."
    else
        log_warning "Redis Secret이 존재하지 않습니다. 수동으로 생성해주세요."
    fi
    
    log_success "ConfigMap 및 Secret 배포 완료"
}

# RBAC 설정 배포
deploy_rbac() {
    log_info "RBAC 설정 배포 중..."
    
    # ServiceAccount 및 RBAC 배포
    envsubst < k8s/rbac/application-service-accounts.yaml | kubectl apply -f -
    
    log_success "RBAC 설정 배포 완료"
}

# 애플리케이션 배포
deploy_applications() {
    log_info "애플리케이션 배포 시작..."
    
    # 1. Frontend 배포
    log_info "Frontend 서비스 배포 중..."
    envsubst < k8s/deployments/frontend-deployment.yaml | kubectl apply -f -
    kubectl apply -f k8s/services/frontend-service.yaml
    
    # 2. Backend 서비스들 배포 (의존성 순서 고려)
    log_info "Catalog Service 배포 중..."
    envsubst < k8s/deployments/catalog-service-deployment.yaml | kubectl apply -f -
    kubectl apply -f k8s/services/catalog-service-service.yaml
    
    log_info "Order Service 배포 중..."
    envsubst < k8s/deployments/order-service-deployment.yaml | kubectl apply -f -
    kubectl apply -f k8s/services/order-service-service.yaml
    
    log_info "Main Service 배포 중..."
    envsubst < k8s/deployments/main-service-deployment.yaml | kubectl apply -f -
    kubectl apply -f k8s/services/main-service-service.yaml
    
    log_success "애플리케이션 배포 완료"
}

# PDB 배포
deploy_pdb() {
    log_info "Pod Disruption Budget 배포 중..."
    
    kubectl apply -f k8s/autoscaling/pod-disruption-budgets.yaml
    
    log_success "Pod Disruption Budget 배포 완료"
}

# 배포 상태 확인
check_deployment_status() {
    log_info "배포 상태 확인 중..."
    
    # Frontend 상태 확인
    log_info "Frontend 서비스 상태 확인..."
    kubectl rollout status deployment/frontend -n frontend --timeout=300s
    
    # Backend 서비스들 상태 확인
    log_info "Catalog Service 상태 확인..."
    kubectl rollout status deployment/catalog-service -n backend --timeout=300s
    
    log_info "Order Service 상태 확인..."
    kubectl rollout status deployment/order-service -n backend --timeout=300s
    
    log_info "Main Service 상태 확인..."
    kubectl rollout status deployment/main-service -n backend --timeout=300s
    
    log_success "모든 서비스가 성공적으로 배포되었습니다!"
}

# 헬스체크 수행
perform_health_checks() {
    log_info "헬스체크 수행 중..."
    
    # Pod 상태 확인
    log_info "Pod 상태:"
    kubectl get pods -n frontend
    kubectl get pods -n backend
    
    # Service 상태 확인
    log_info "Service 상태:"
    kubectl get svc -n frontend
    kubectl get svc -n backend
    
    # 헬스체크 엔드포인트 테스트 (포트 포워딩 사용)
    log_info "헬스체크 엔드포인트 테스트..."
    
    # Main Service 헬스체크
    kubectl port-forward -n backend svc/main-service 3001:3001 &
    PORT_FORWARD_PID=$!
    sleep 5
    
    if curl -f http://localhost:3001/health &> /dev/null; then
        log_success "Main Service 헬스체크 성공"
    else
        log_warning "Main Service 헬스체크 실패"
    fi
    
    kill $PORT_FORWARD_PID 2>/dev/null || true
    
    log_success "헬스체크 완료"
}

# 배포 정보 출력
print_deployment_info() {
    log_info "배포 정보:"
    echo "=================================="
    echo "Frontend Namespace: frontend"
    echo "Backend Namespace: backend"
    echo ""
    echo "Services:"
    echo "- Frontend: http://frontend-service.frontend.svc.cluster.local"
    echo "- Main Service: http://main-service.backend.svc.cluster.local:3001"
    echo "- Catalog Service: http://catalog-service.backend.svc.cluster.local:8000"
    echo "- Order Service: http://order-service.backend.svc.cluster.local:8080"
    echo ""
    echo "다음 명령어로 서비스 상태를 확인할 수 있습니다:"
    echo "kubectl get pods -n frontend"
    echo "kubectl get pods -n backend"
    echo "kubectl get svc -n frontend"
    echo "kubectl get svc -n backend"
    echo "=================================="
}

# 메인 실행 함수
main() {
    log_info "EKS MSA Learning Platform 애플리케이션 배포 시작"
    
    check_prerequisites
    create_namespaces
    deploy_configs
    deploy_rbac
    deploy_applications
    deploy_pdb
    check_deployment_status
    perform_health_checks
    print_deployment_info
    
    log_success "배포가 성공적으로 완료되었습니다!"
}

# 스크립트 실행
main "$@"