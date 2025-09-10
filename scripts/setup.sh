#!/bin/bash

# EKS MSA Learning Platform 설정 스크립트

set -e

echo "🚀 EKS MSA Learning Platform 설정을 시작합니다..."

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# 사전 요구사항 확인
check_prerequisites() {
    log_info "사전 요구사항을 확인합니다..."
    
    # AWS CLI 확인
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI가 설치되지 않았습니다."
        exit 1
    fi
    
    # Terraform 확인
    if ! command -v terraform &> /dev/null; then
        log_error "Terraform이 설치되지 않았습니다."
        exit 1
    fi
    
    # kubectl 확인
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl이 설치되지 않았습니다."
        exit 1
    fi
    
    # Helm 확인
    if ! command -v helm &> /dev/null; then
        log_error "Helm이 설치되지 않았습니다."
        exit 1
    fi
    
    log_info "모든 사전 요구사항이 충족되었습니다."
}

# AWS 자격증명 확인
check_aws_credentials() {
    log_info "AWS 자격증명을 확인합니다..."
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS 자격증명이 설정되지 않았습니다."
        log_info "다음 명령어로 AWS CLI를 설정하세요: aws configure"
        exit 1
    fi
    
    log_info "AWS 자격증명이 확인되었습니다."
}

# 환경 변수 파일 생성
create_env_files() {
    log_info "환경 변수 파일을 생성합니다..."
    
    # Terraform 변수 파일 복사
    if [ ! -f "terraform/terraform.tfvars" ]; then
        cp terraform/terraform.tfvars.example terraform/terraform.tfvars
        log_info "terraform.tfvars 파일이 생성되었습니다. 필요에 따라 수정하세요."
    fi
}

# 메인 실행
main() {
    check_prerequisites
    check_aws_credentials
    create_env_files
    
    log_info "설정이 완료되었습니다!"
    log_info "다음 단계:"
    log_info "1. terraform/terraform.tfvars 파일을 검토하고 수정하세요"
    log_info "2. terraform 디렉토리에서 'terraform init && terraform apply'를 실행하세요"
}

main "$@"