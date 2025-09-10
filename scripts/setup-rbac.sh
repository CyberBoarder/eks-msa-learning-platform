#!/bin/bash

# RBAC 및 보안 설정 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 함수 정의
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 환경 변수 확인
check_environment() {
    log_info "환경 변수를 확인합니다..."
    
    if [ -z "$CLUSTER_NAME" ]; then
        log_error "CLUSTER_NAME 환경 변수가 설정되지 않았습니다."
        exit 1
    fi
    
    log_info "환경 변수 확인 완료: CLUSTER_NAME=$CLUSTER_NAME"
}

# kubectl 연결 확인
check_kubectl() {
    log_info "kubectl 연결을 확인합니다..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl이 클러스터에 연결할 수 없습니다."
        exit 1
    fi
    
    log_info "kubectl 연결 확인 완료"
}

# 네임스페이스 생성 (Pod Security Standards 포함)
create_namespaces() {
    log_step "네임스페이스를 생성합니다 (Pod Security Standards 포함)..."
    
    kubectl apply -f k8s/security/pod-security-standards.yaml
    
    # 네임스페이스가 생성될 때까지 대기
    for ns in frontend backend monitoring security chaos gitops; do
        kubectl wait --for=condition=Active namespace/$ns --timeout=60s
        log_info "네임스페이스 '$ns' 생성 완료"
    done
}

# ServiceAccount 생성
create_service_accounts() {
    log_step "ServiceAccount를 생성합니다..."
    
    # 환경 변수가 설정되지 않은 경우 기본값 사용
    export FRONTEND_SERVICE_ROLE_ARN=${FRONTEND_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-frontend-service-role"}
    export MAIN_SERVICE_ROLE_ARN=${MAIN_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-main-service-role"}
    export CATALOG_SERVICE_ROLE_ARN=${CATALOG_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-catalog-service-role"}
    export ORDER_SERVICE_ROLE_ARN=${ORDER_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-order-service-role"}
    export MONITORING_SERVICE_ROLE_ARN=${MONITORING_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-monitoring-service-role"}
    export SECURITY_SERVICE_ROLE_ARN=${SECURITY_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-security-service-role"}
    export CHAOS_SERVICE_ROLE_ARN=${CHAOS_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-chaos-service-role"}
    export GITOPS_SERVICE_ROLE_ARN=${GITOPS_SERVICE_ROLE_ARN:-"arn:aws:iam::${AWS_ACCOUNT_ID}:role/${CLUSTER_NAME}-gitops-service-role"}
    
    envsubst < k8s/rbac/service-accounts.yaml | kubectl apply -f -
    
    log_info "ServiceAccount 생성 완료"
}

# ClusterRole 생성
create_cluster_roles() {
    log_step "ClusterRole을 생성합니다..."
    
    kubectl apply -f k8s/rbac/cluster-roles.yaml
    
    log_info "ClusterRole 생성 완료"
}

# RoleBinding 및 ClusterRoleBinding 생성
create_role_bindings() {
    log_step "RoleBinding 및 ClusterRoleBinding을 생성합니다..."
    
    kubectl apply -f k8s/rbac/role-bindings.yaml
    
    log_info "RoleBinding 및 ClusterRoleBinding 생성 완료"
}

# Network Policy 적용
apply_network_policies() {
    log_step "Network Policy를 적용합니다..."
    
    # Calico 또는 다른 CNI가 Network Policy를 지원하는지 확인
    if kubectl get crd networkpolicies.networking.k8s.io &> /dev/null; then
        kubectl apply -f k8s/security/network-policies.yaml
        log_info "Network Policy 적용 완료"
    else
        log_warn "Network Policy가 지원되지 않습니다. CNI 플러그인을 확인하세요."
    fi
}

# AWS IAM 역할 생성 (선택사항)
create_iam_roles() {
    log_step "AWS IAM 역할을 생성합니다 (선택사항)..."
    
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    fi
    
    # OIDC Provider URL 가져오기
    OIDC_URL=$(aws eks describe-cluster --name $CLUSTER_NAME --query "cluster.identity.oidc.issuer" --output text)
    OIDC_ID=${OIDC_URL##*/}
    
    log_info "OIDC Provider: $OIDC_URL"
    log_info "OIDC ID: $OIDC_ID"
    
    # 각 서비스별 IAM 역할 생성 스크립트 실행 (별도 구현 필요)
    if [ -f "scripts/create-iam-roles.sh" ]; then
        ./scripts/create-iam-roles.sh
    else
        log_warn "IAM 역할 생성 스크립트가 없습니다. 수동으로 생성하세요."
    fi
}

# RBAC 설정 확인
verify_rbac() {
    log_step "RBAC 설정을 확인합니다..."
    
    echo ""
    log_info "=== 네임스페이스 확인 ==="
    kubectl get namespaces -l app.kubernetes.io/part-of=eks-msa-learning
    
    echo ""
    log_info "=== ServiceAccount 확인 ==="
    for ns in frontend backend monitoring security chaos gitops; do
        echo "Namespace: $ns"
        kubectl get serviceaccounts -n $ns -l app.kubernetes.io/part-of=eks-msa-learning
        echo ""
    done
    
    echo ""
    log_info "=== ClusterRole 확인 ==="
    kubectl get clusterroles -l app.kubernetes.io/part-of=eks-msa-learning
    
    echo ""
    log_info "=== ClusterRoleBinding 확인 ==="
    kubectl get clusterrolebindings -l app.kubernetes.io/part-of=eks-msa-learning
    
    echo ""
    log_info "=== Network Policy 확인 ==="
    for ns in frontend backend monitoring security chaos; do
        echo "Namespace: $ns"
        kubectl get networkpolicies -n $ns 2>/dev/null || echo "  No network policies found"
        echo ""
    done
    
    echo ""
    log_info "=== Pod Security Standards 확인 ==="
    kubectl get namespaces -o custom-columns=NAME:.metadata.name,ENFORCE:.metadata.labels.pod-security\\.kubernetes\\.io/enforce,AUDIT:.metadata.labels.pod-security\\.kubernetes\\.io/audit,WARN:.metadata.labels.pod-security\\.kubernetes\\.io/warn | grep -E "(frontend|backend|monitoring|security|chaos|gitops)"
}

# 권한 테스트
test_permissions() {
    log_step "권한을 테스트합니다..."
    
    # Frontend ServiceAccount 권한 테스트
    log_info "Frontend ServiceAccount 권한 테스트..."
    kubectl auth can-i get pods --as=system:serviceaccount:frontend:frontend-service-account -n frontend
    kubectl auth can-i create deployments --as=system:serviceaccount:frontend:frontend-service-account -n frontend
    kubectl auth can-i delete secrets --as=system:serviceaccount:frontend:frontend-service-account -n backend && log_warn "Frontend가 backend 네임스페이스에 접근할 수 있습니다!" || log_info "Frontend의 backend 접근이 올바르게 차단되었습니다."
    
    # Backend ServiceAccount 권한 테스트
    log_info "Backend ServiceAccount 권한 테스트..."
    kubectl auth can-i get configmaps --as=system:serviceaccount:backend:main-service-account -n backend
    kubectl auth can-i create pods --as=system:serviceaccount:backend:catalog-service-account -n backend
    
    log_info "권한 테스트 완료"
}

# 메인 실행
main() {
    log_info "🔐 RBAC 및 보안 설정을 시작합니다..."
    
    check_environment
    check_kubectl
    
    create_namespaces
    create_service_accounts
    create_cluster_roles
    create_role_bindings
    apply_network_policies
    
    # IAM 역할 생성은 선택사항
    if [ "$CREATE_IAM_ROLES" = "true" ]; then
        create_iam_roles
    fi
    
    verify_rbac
    test_permissions
    
    log_info "✅ RBAC 및 보안 설정이 완료되었습니다!"
    log_info ""
    log_info "다음 단계:"
    log_info "1. 애플리케이션 배포 시 적절한 ServiceAccount 사용"
    log_info "2. Pod Security Standards 준수 확인"
    log_info "3. Network Policy 동작 테스트"
    log_info "4. 필요시 추가 권한 설정"
}

main "$@"