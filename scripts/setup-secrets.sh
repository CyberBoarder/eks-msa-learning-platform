#!/bin/bash

# EKS MSA Learning Platform - Secrets 및 ConfigMap 설정 스크립트
# 이 스크립트는 Kubernetes Secrets, ConfigMaps, External Secrets Operator를 설정합니다.

set -e

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
check_environment() {
    log_info "환경 변수 확인 중..."
    
    # 필수 환경 변수 목록
    required_vars=(
        "CLUSTER_NAME"
        "AWS_REGION"
        "RDS_ENDPOINT"
        "REDIS_ENDPOINT"
        "S3_BUCKET_NAME"
    )
    
    missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        log_error "다음 환경 변수가 설정되지 않았습니다:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        log_error "환경 변수를 설정한 후 다시 실행해주세요."
        exit 1
    fi
    
    log_success "모든 필수 환경 변수가 설정되었습니다."
}

# kubectl 연결 확인
check_kubectl() {
    log_info "kubectl 연결 확인 중..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl이 클러스터에 연결할 수 없습니다."
        log_error "다음 명령어로 kubeconfig를 설정해주세요:"
        echo "aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME"
        exit 1
    fi
    
    log_success "kubectl 연결이 확인되었습니다."
}

# Base64 인코딩 함수
base64_encode() {
    echo -n "$1" | base64 -w 0
}

# 네임스페이스 생성
create_namespaces() {
    log_info "네임스페이스 생성 중..."
    
    # 네임스페이스가 이미 존재하는지 확인하고 생성
    namespaces=("frontend" "backend" "monitoring" "external-secrets-system")
    
    for ns in "${namespaces[@]}"; do
        if kubectl get namespace "$ns" &> /dev/null; then
            log_warning "네임스페이스 '$ns'가 이미 존재합니다."
        else
            kubectl create namespace "$ns"
            log_success "네임스페이스 '$ns'가 생성되었습니다."
        fi
    done
}

# ConfigMap 적용
apply_configmaps() {
    log_info "ConfigMap 적용 중..."
    
    # ConfigMap 파일 적용
    if [ -f "k8s/config/application-configmaps.yaml" ]; then
        kubectl apply -f k8s/config/application-configmaps.yaml
        log_success "애플리케이션 ConfigMap이 적용되었습니다."
    else
        log_error "ConfigMap 파일을 찾을 수 없습니다: k8s/config/application-configmaps.yaml"
        exit 1
    fi
}

# 기본 Secrets 생성 (External Secrets Operator 설치 전 임시용)
create_basic_secrets() {
    log_info "기본 Secrets 생성 중..."
    
    # 환경 변수를 Base64로 인코딩
    RDS_ENDPOINT_BASE64=$(base64_encode "$RDS_ENDPOINT")
    REDIS_ENDPOINT_BASE64=$(base64_encode "$REDIS_ENDPOINT")
    S3_BUCKET_NAME_BASE64=$(base64_encode "$S3_BUCKET_NAME")
    CATALOG_DATABASE_URL_BASE64=$(base64_encode "postgresql://dbadmin:changeme123!@$RDS_ENDPOINT:5432/catalog_db")
    ORDER_DATABASE_URL_BASE64=$(base64_encode "jdbc:postgresql://$RDS_ENDPOINT:5432/order_db")
    REDIS_URL_BASE64=$(base64_encode "redis://$REDIS_ENDPOINT:6379")
    
    # 임시 Secrets 파일 생성
    temp_secrets_file="/tmp/database-secrets-temp.yaml"
    
    # 템플릿 파일을 복사하고 환경 변수로 치환
    sed -e "s/\${RDS_ENDPOINT_BASE64}/$RDS_ENDPOINT_BASE64/g" \
        -e "s/\${REDIS_ENDPOINT_BASE64}/$REDIS_ENDPOINT_BASE64/g" \
        -e "s/\${S3_BUCKET_NAME_BASE64}/$S3_BUCKET_NAME_BASE64/g" \
        -e "s/\${CATALOG_DATABASE_URL_BASE64}/$CATALOG_DATABASE_URL_BASE64/g" \
        -e "s/\${ORDER_DATABASE_URL_BASE64}/$ORDER_DATABASE_URL_BASE64/g" \
        -e "s/\${REDIS_URL_BASE64}/$REDIS_URL_BASE64/g" \
        k8s/secrets/database-secrets.yaml > "$temp_secrets_file"
    
    # Secrets 적용
    kubectl apply -f "$temp_secrets_file"
    
    # 임시 파일 삭제
    rm "$temp_secrets_file"
    
    log_success "기본 Secrets가 생성되었습니다."
}

# External Secrets Operator 설치
install_external_secrets_operator() {
    log_info "External Secrets Operator 설치 중..."
    
    # Helm 리포지토리 추가
    if ! helm repo list | grep -q "external-secrets"; then
        helm repo add external-secrets https://charts.external-secrets.io
        log_success "External Secrets Helm 리포지토리가 추가되었습니다."
    else
        log_warning "External Secrets Helm 리포지토리가 이미 존재합니다."
    fi
    
    helm repo update
    
    # External Secrets Operator가 이미 설치되어 있는지 확인
    if helm list -n external-secrets-system | grep -q "external-secrets"; then
        log_warning "External Secrets Operator가 이미 설치되어 있습니다."
        return
    fi
    
    # IRSA 역할 ARN 확인
    if [ -z "$EXTERNAL_SECRETS_ROLE_ARN" ]; then
        log_warning "EXTERNAL_SECRETS_ROLE_ARN이 설정되지 않았습니다."
        log_warning "IRSA 없이 External Secrets Operator를 설치합니다."
        
        # IRSA 없이 설치
        helm install external-secrets external-secrets/external-secrets \
            --namespace external-secrets-system \
            --create-namespace \
            --set installCRDs=true \
            --wait
    else
        # ServiceAccount 생성 (IRSA 포함)
        kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: external-secrets-operator
  namespace: external-secrets-system
  annotations:
    eks.amazonaws.com/role-arn: $EXTERNAL_SECRETS_ROLE_ARN
EOF
        
        # IRSA와 함께 설치
        helm install external-secrets external-secrets/external-secrets \
            --namespace external-secrets-system \
            --create-namespace \
            --set serviceAccount.create=false \
            --set serviceAccount.name=external-secrets-operator \
            --set installCRDs=true \
            --wait
    fi
    
    log_success "External Secrets Operator가 설치되었습니다."
}

# AWS Secrets Manager에 시크릿 생성
create_aws_secrets() {
    log_info "AWS Secrets Manager에 시크릿 생성 중..."
    
    # RDS 자격증명 생성
    if aws secretsmanager describe-secret --secret-id "eks-msa-learning/rds-credentials" --region "$AWS_REGION" &> /dev/null; then
        log_warning "RDS 자격증명이 이미 존재합니다. 업데이트합니다."
        aws secretsmanager update-secret \
            --secret-id "eks-msa-learning/rds-credentials" \
            --secret-string "{
                \"username\": \"dbadmin\",
                \"password\": \"changeme123!\",
                \"host\": \"$RDS_ENDPOINT\",
                \"port\": \"5432\",
                \"database\": \"msalearning\"
            }" \
            --region "$AWS_REGION" > /dev/null
    else
        aws secretsmanager create-secret \
            --name "eks-msa-learning/rds-credentials" \
            --description "RDS PostgreSQL credentials for EKS MSA Learning Platform" \
            --secret-string "{
                \"username\": \"dbadmin\",
                \"password\": \"changeme123!\",
                \"host\": \"$RDS_ENDPOINT\",
                \"port\": \"5432\",
                \"database\": \"msalearning\"
            }" \
            --region "$AWS_REGION" > /dev/null
    fi
    log_success "RDS 자격증명이 생성/업데이트되었습니다."
    
    # Redis 자격증명 생성
    if aws secretsmanager describe-secret --secret-id "eks-msa-learning/redis-credentials" --region "$AWS_REGION" &> /dev/null; then
        log_warning "Redis 자격증명이 이미 존재합니다. 업데이트합니다."
        aws secretsmanager update-secret \
            --secret-id "eks-msa-learning/redis-credentials" \
            --secret-string "{
                \"host\": \"$REDIS_ENDPOINT\",
                \"port\": \"6379\",
                \"password\": \"\"
            }" \
            --region "$AWS_REGION" > /dev/null
    else
        aws secretsmanager create-secret \
            --name "eks-msa-learning/redis-credentials" \
            --description "Redis credentials for EKS MSA Learning Platform" \
            --secret-string "{
                \"host\": \"$REDIS_ENDPOINT\",
                \"port\": \"6379\",
                \"password\": \"\"
            }" \
            --region "$AWS_REGION" > /dev/null
    fi
    log_success "Redis 자격증명이 생성/업데이트되었습니다."
    
    # S3 설정 생성
    if aws secretsmanager describe-secret --secret-id "eks-msa-learning/s3-config" --region "$AWS_REGION" &> /dev/null; then
        log_warning "S3 설정이 이미 존재합니다. 업데이트합니다."
        aws secretsmanager update-secret \
            --secret-id "eks-msa-learning/s3-config" \
            --secret-string "{
                \"bucket_name\": \"$S3_BUCKET_NAME\",
                \"region\": \"$AWS_REGION\"
            }" \
            --region "$AWS_REGION" > /dev/null
    else
        aws secretsmanager create-secret \
            --name "eks-msa-learning/s3-config" \
            --description "S3 configuration for EKS MSA Learning Platform" \
            --secret-string "{
                \"bucket_name\": \"$S3_BUCKET_NAME\",
                \"region\": \"$AWS_REGION\"
            }" \
            --region "$AWS_REGION" > /dev/null
    fi
    log_success "S3 설정이 생성/업데이트되었습니다."
    
    # 모니터링 설정 생성
    if aws secretsmanager describe-secret --secret-id "eks-msa-learning/monitoring-config" --region "$AWS_REGION" &> /dev/null; then
        log_warning "모니터링 설정이 이미 존재합니다."
    else
        aws secretsmanager create-secret \
            --name "eks-msa-learning/monitoring-config" \
            --description "Monitoring configuration for EKS MSA Learning Platform" \
            --secret-string "{
                \"slack_webhook_url\": \"https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK\",
                \"slack_channel\": \"#eks-msa-alerts\",
                \"grafana_admin_password\": \"admin123!\"
            }" \
            --region "$AWS_REGION" > /dev/null
        log_success "모니터링 설정이 생성되었습니다."
    fi
}

# External Secrets 리소스 적용
apply_external_secrets() {
    log_info "External Secrets 리소스 적용 중..."
    
    if [ -z "$EXTERNAL_SECRETS_ROLE_ARN" ]; then
        log_warning "EXTERNAL_SECRETS_ROLE_ARN이 설정되지 않아 External Secrets 리소스를 건너뜁니다."
        return
    fi
    
    # 환경 변수 치환하여 임시 파일 생성
    temp_external_secrets_file="/tmp/external-secrets-temp.yaml"
    
    sed -e "s/\${EXTERNAL_SECRETS_ROLE_ARN}/$EXTERNAL_SECRETS_ROLE_ARN/g" \
        k8s/external-secrets/external-secrets-operator.yaml > "$temp_external_secrets_file"
    
    # External Secrets 리소스 적용
    kubectl apply -f "$temp_external_secrets_file"
    
    # 임시 파일 삭제
    rm "$temp_external_secrets_file"
    
    log_success "External Secrets 리소스가 적용되었습니다."
}

# 설치 확인
verify_installation() {
    log_info "설치 확인 중..."
    
    # ConfigMap 확인
    log_info "ConfigMap 상태 확인:"
    kubectl get configmaps -n frontend
    kubectl get configmaps -n backend
    
    # Secrets 확인
    log_info "Secrets 상태 확인:"
    kubectl get secrets -n frontend
    kubectl get secrets -n backend
    
    # External Secrets Operator 확인
    if kubectl get pods -n external-secrets-system &> /dev/null; then
        log_info "External Secrets Operator Pod 상태:"
        kubectl get pods -n external-secrets-system
        
        # CRD 확인
        log_info "External Secrets CRD 확인:"
        kubectl get crd | grep external-secrets || log_warning "External Secrets CRD를 찾을 수 없습니다."
    else
        log_warning "External Secrets Operator가 설치되지 않았습니다."
    fi
    
    log_success "설치 확인이 완료되었습니다."
}

# 사용법 출력
usage() {
    echo "사용법: $0 [옵션]"
    echo ""
    echo "옵션:"
    echo "  --skip-aws-secrets    AWS Secrets Manager 생성을 건너뜁니다"
    echo "  --skip-external-secrets    External Secrets Operator 설치를 건너뜁니다"
    echo "  --help                이 도움말을 출력합니다"
    echo ""
    echo "필수 환경 변수:"
    echo "  CLUSTER_NAME          EKS 클러스터 이름"
    echo "  AWS_REGION           AWS 리전 (기본값: ap-northeast-1)"
    echo "  RDS_ENDPOINT         RDS PostgreSQL 엔드포인트"
    echo "  REDIS_ENDPOINT       ElastiCache Redis 엔드포인트"
    echo "  S3_BUCKET_NAME       S3 버킷 이름"
    echo ""
    echo "선택적 환경 변수:"
    echo "  EXTERNAL_SECRETS_ROLE_ARN    External Secrets Operator IRSA 역할 ARN"
}

# 메인 함수
main() {
    local skip_aws_secrets=false
    local skip_external_secrets=false
    
    # 명령행 인수 처리
    while [[ $# -gt 0 ]]; do
        case $1 in
            --skip-aws-secrets)
                skip_aws_secrets=true
                shift
                ;;
            --skip-external-secrets)
                skip_external_secrets=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            *)
                log_error "알 수 없는 옵션: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # 기본값 설정
    AWS_REGION=${AWS_REGION:-"ap-northeast-1"}
    
    log_info "EKS MSA Learning Platform - Secrets 및 ConfigMap 설정 시작"
    log_info "클러스터: $CLUSTER_NAME"
    log_info "리전: $AWS_REGION"
    
    # 실행 단계
    check_environment
    check_kubectl
    create_namespaces
    apply_configmaps
    create_basic_secrets
    
    if [ "$skip_external_secrets" = false ]; then
        install_external_secrets_operator
        
        if [ "$skip_aws_secrets" = false ]; then
            create_aws_secrets
            apply_external_secrets
        else
            log_warning "AWS Secrets Manager 생성을 건너뜁니다."
        fi
    else
        log_warning "External Secrets Operator 설치를 건너뜁니다."
    fi
    
    verify_installation
    
    log_success "모든 설정이 완료되었습니다!"
    
    # 다음 단계 안내
    echo ""
    log_info "다음 단계:"
    echo "1. 애플리케이션 배포: kubectl apply -f k8s/deployments/"
    echo "2. 모니터링 설정: helm install prometheus monitoring/prometheus/"
    echo "3. 상태 확인: kubectl get all -A"
}

# 스크립트 실행
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi