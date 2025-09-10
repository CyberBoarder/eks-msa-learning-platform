#!/bin/bash

# EKS 필수 애드온 설치 스크립트

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
    
    if [ -z "$AWS_REGION" ]; then
        log_error "AWS_REGION 환경 변수가 설정되지 않았습니다."
        exit 1
    fi
    
    log_info "환경 변수 확인 완료: CLUSTER_NAME=$CLUSTER_NAME, AWS_REGION=$AWS_REGION"
}

# kubectl 연결 확인
check_kubectl() {
    log_info "kubectl 연결을 확인합니다..."
    
    if ! kubectl cluster-info &> /dev/null; then
        log_error "kubectl이 클러스터에 연결할 수 없습니다."
        log_info "다음 명령어로 kubeconfig를 설정하세요:"
        log_info "aws eks --region $AWS_REGION update-kubeconfig --name $CLUSTER_NAME"
        exit 1
    fi
    
    log_info "kubectl 연결 확인 완료"
}

# Helm 설치 확인
check_helm() {
    log_info "Helm 설치를 확인합니다..."
    
    if ! command -v helm &> /dev/null; then
        log_error "Helm이 설치되지 않았습니다."
        log_info "Helm 설치: https://helm.sh/docs/intro/install/"
        exit 1
    fi
    
    log_info "Helm 버전: $(helm version --short)"
}

# AWS Load Balancer Controller 설치
install_aws_load_balancer_controller() {
    log_step "AWS Load Balancer Controller를 설치합니다..."
    
    # Helm 리포지토리 추가
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    
    # CRD 설치
    kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
    
    # ServiceAccount 생성 (IRSA 설정)
    if ! kubectl get serviceaccount aws-load-balancer-controller -n kube-system &> /dev/null; then
        kubectl create serviceaccount aws-load-balancer-controller -n kube-system
        kubectl annotate serviceaccount aws-load-balancer-controller -n kube-system \
            eks.amazonaws.com/role-arn=$AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN
    fi
    
    # Helm으로 설치
    helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=$CLUSTER_NAME \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller \
        --set region=$AWS_REGION \
        --set vpcId=$VPC_ID \
        --set image.repository=602401143452.dkr.ecr.$AWS_REGION.amazonaws.com/amazon/aws-load-balancer-controller
    
    log_info "AWS Load Balancer Controller 설치 완료"
}

# EBS CSI Driver 설치
install_ebs_csi_driver() {
    log_step "EBS CSI Driver를 설치합니다..."
    
    # EKS 애드온으로 설치
    aws eks create-addon \
        --cluster-name $CLUSTER_NAME \
        --addon-name aws-ebs-csi-driver \
        --service-account-role-arn $EBS_CSI_DRIVER_ROLE_ARN \
        --resolve-conflicts OVERWRITE \
        --region $AWS_REGION || log_warn "EBS CSI Driver 애드온이 이미 존재하거나 설치 중입니다."
    
    # StorageClass 적용
    kubectl apply -f k8s/addons/ebs-csi-driver.yaml
    
    log_info "EBS CSI Driver 설치 완료"
}

# EFS CSI Driver 설치
install_efs_csi_driver() {
    log_step "EFS CSI Driver를 설치합니다..."
    
    # Helm 리포지토리 추가
    helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
    helm repo update
    
    # ServiceAccount 생성 (IRSA 설정)
    if ! kubectl get serviceaccount efs-csi-controller-sa -n kube-system &> /dev/null; then
        kubectl create serviceaccount efs-csi-controller-sa -n kube-system
        kubectl annotate serviceaccount efs-csi-controller-sa -n kube-system \
            eks.amazonaws.com/role-arn=$EFS_CSI_DRIVER_ROLE_ARN
    fi
    
    # Helm으로 설치
    helm upgrade --install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
        -n kube-system \
        --set controller.serviceAccount.create=false \
        --set controller.serviceAccount.name=efs-csi-controller-sa
    
    # StorageClass 및 PV 적용
    envsubst < k8s/addons/efs-csi-driver.yaml | kubectl apply -f -
    
    log_info "EFS CSI Driver 설치 완료"
}

# Metrics Server 설치
install_metrics_server() {
    log_step "Metrics Server를 설치합니다..."
    
    kubectl apply -f k8s/addons/metrics-server.yaml
    
    # Metrics Server가 준비될 때까지 대기
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    
    log_info "Metrics Server 설치 완료"
}

# Cluster Autoscaler 설치
install_cluster_autoscaler() {
    log_step "Cluster Autoscaler를 설치합니다..."
    
    # ServiceAccount 생성 (IRSA 설정)
    if ! kubectl get serviceaccount cluster-autoscaler -n kube-system &> /dev/null; then
        kubectl create serviceaccount cluster-autoscaler -n kube-system
        kubectl annotate serviceaccount cluster-autoscaler -n kube-system \
            eks.amazonaws.com/role-arn=$CLUSTER_AUTOSCALER_ROLE_ARN
    fi
    
    # Cluster Autoscaler 배포
    envsubst < k8s/addons/cluster-autoscaler.yaml | kubectl apply -f -
    
    log_info "Cluster Autoscaler 설치 완료"
}

# 네임스페이스 생성
create_namespaces() {
    log_step "네임스페이스를 생성합니다..."
    
    kubectl apply -f k8s/namespaces/namespaces.yaml
    
    log_info "네임스페이스 생성 완료"
}

# 설치 상태 확인
check_installation() {
    log_step "설치 상태를 확인합니다..."
    
    echo ""
    log_info "=== Pod 상태 확인 ==="
    kubectl get pods -n kube-system | grep -E "(aws-load-balancer-controller|ebs-csi|efs-csi|metrics-server|cluster-autoscaler)"
    
    echo ""
    log_info "=== StorageClass 확인 ==="
    kubectl get storageclass
    
    echo ""
    log_info "=== 네임스페이스 확인 ==="
    kubectl get namespaces | grep -E "(frontend|backend|monitoring|security|chaos|gitops)"
    
    echo ""
    log_info "=== Metrics Server 동작 확인 ==="
    kubectl top nodes || log_warn "Metrics Server가 아직 준비되지 않았습니다. 잠시 후 다시 확인해주세요."
}

# 메인 실행
main() {
    log_info "🚀 EKS 필수 애드온 설치를 시작합니다..."
    
    check_environment
    check_kubectl
    check_helm
    
    create_namespaces
    install_metrics_server
    install_aws_load_balancer_controller
    install_ebs_csi_driver
    install_efs_csi_driver
    install_cluster_autoscaler
    
    check_installation
    
    log_info "✅ 모든 애드온 설치가 완료되었습니다!"
    log_info ""
    log_info "다음 단계:"
    log_info "1. 애플리케이션 배포"
    log_info "2. 모니터링 스택 설치"
    log_info "3. 보안 도구 설치"
}

main "$@"