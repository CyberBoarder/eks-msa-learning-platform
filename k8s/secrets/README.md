# Secrets 및 ConfigMap 관리 가이드

이 디렉토리는 EKS MSA 학습 플랫폼의 Secrets와 ConfigMap 관리를 위한 리소스들을 포함합니다.

## 구조

```
k8s/
├── secrets/
│   ├── database-secrets.yaml      # 데이터베이스 연결 정보
│   └── README.md                   # 이 파일
├── config/
│   └── application-configmaps.yaml # 애플리케이션 설정
└── external-secrets/
    ├── external-secrets-operator.yaml  # External Secrets 리소스
    └── install-external-secrets.yaml   # 설치 가이드
```

## 주요 구성 요소

### 1. Database Secrets (`database-secrets.yaml`)

데이터베이스 연결에 필요한 민감한 정보를 저장합니다:

- **postgres-credentials**: RDS PostgreSQL 기본 연결 정보
- **catalog-db-credentials**: Catalog Service용 데이터베이스 설정
- **order-db-credentials**: Order Service용 데이터베이스 설정
- **redis-credentials**: ElastiCache Redis 연결 정보
- **s3-credentials**: S3 버킷 접근 설정

### 2. Application ConfigMaps (`application-configmaps.yaml`)

애플리케이션 설정 정보를 저장합니다:

- **frontend-config**: React 애플리케이션 및 Nginx 설정
- **main-service-config**: API Gateway 서비스 설정
- **catalog-service-config**: Catalog Service 설정
- **order-service-config**: Order Service 설정
- **monitoring-config**: 모니터링 관련 설정
- **security-config**: 보안 관련 설정

### 3. External Secrets Operator

AWS Secrets Manager와 연동하여 Kubernetes Secret을 자동으로 동기화합니다:

- **ClusterSecretStore**: AWS Secrets Manager 연결 설정
- **ExternalSecret**: 각 서비스별 시크릿 동기화 설정

## 설치 및 설정

### 1. 자동 설치 (권장)

```bash
# 환경 변수 설정
export CLUSTER_NAME="eks-msa-learning-dev"
export AWS_REGION="ap-northeast-1"
export RDS_ENDPOINT="your-rds-endpoint.region.rds.amazonaws.com"
export REDIS_ENDPOINT="your-redis-endpoint.region.cache.amazonaws.com"
export S3_BUCKET_NAME="your-s3-bucket-name"
export EXTERNAL_SECRETS_ROLE_ARN="arn:aws:iam::account:role/external-secrets-operator"

# 설정 스크립트 실행
./scripts/setup-secrets.sh
```

### 2. 수동 설치

#### 2.1 네임스페이스 생성
```bash
kubectl apply -f k8s/namespaces/namespaces.yaml
```

#### 2.2 ConfigMap 적용
```bash
kubectl apply -f k8s/config/application-configmaps.yaml
```

#### 2.3 기본 Secrets 생성
```bash
# 환경 변수를 실제 값으로 치환하여 적용
envsubst < k8s/secrets/database-secrets.yaml | kubectl apply -f -
```

#### 2.4 External Secrets Operator 설치
```bash
# Helm 리포지토리 추가
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# 설치
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system \
  --create-namespace \
  --set installCRDs=true
```

#### 2.5 AWS Secrets Manager 설정
```bash
# RDS 자격증명 생성
aws secretsmanager create-secret \
  --name "eks-msa-learning/rds-credentials" \
  --secret-string '{
    "username": "dbadmin",
    "password": "changeme123!",
    "host": "your-rds-endpoint",
    "port": "5432",
    "database": "msalearning"
  }' \
  --region ap-northeast-1
```

## 보안 고려사항

### 1. 비밀번호 관리
- 기본 비밀번호(`changeme123!`)는 반드시 변경해야 합니다
- AWS Secrets Manager를 통해 비밀번호를 안전하게 관리하세요
- 정기적으로 비밀번호를 로테이션하세요

### 2. IRSA (IAM Roles for Service Accounts)
- External Secrets Operator는 IRSA를 사용하여 AWS 리소스에 접근합니다
- 최소 권한 원칙에 따라 필요한 권한만 부여하세요

### 3. 네트워크 보안
- 데이터베이스는 프라이빗 서브넷에 배치하세요
- 보안 그룹을 통해 필요한 포트만 허용하세요

## 트러블슈팅

### 1. Secret이 생성되지 않는 경우
```bash
# Secret 상태 확인
kubectl get secrets -n backend
kubectl describe secret postgres-credentials -n backend

# External Secrets 상태 확인
kubectl get externalsecrets -n backend
kubectl describe externalsecret rds-credentials -n backend
```

### 2. External Secrets Operator 문제
```bash
# Pod 로그 확인
kubectl logs -n external-secrets-system -l app.kubernetes.io/name=external-secrets

# IRSA 설정 확인
kubectl get sa external-secrets-operator -n external-secrets-system -o yaml
```

### 3. AWS Secrets Manager 연결 문제
```bash
# AWS CLI로 시크릿 확인
aws secretsmanager get-secret-value --secret-id "eks-msa-learning/rds-credentials"

# IAM 역할 권한 확인
aws sts get-caller-identity
```

## 모니터링

### 1. Secret 동기화 상태 모니터링
```bash
# External Secrets 상태 확인
kubectl get externalsecrets -A

# 동기화 실패 이벤트 확인
kubectl get events -n backend --field-selector reason=SecretSyncError
```

### 2. 메트릭 수집
External Secrets Operator는 Prometheus 메트릭을 제공합니다:
- `externalsecrets_sync_calls_total`: 동기화 호출 횟수
- `externalsecrets_sync_calls_error`: 동기화 실패 횟수

## 업데이트 및 유지보수

### 1. Secret 값 업데이트
```bash
# AWS Secrets Manager에서 값 업데이트
aws secretsmanager update-secret \
  --secret-id "eks-msa-learning/rds-credentials" \
  --secret-string '{"username": "newuser", "password": "newpassword"}'

# External Secrets가 자동으로 동기화됩니다 (기본 1시간 간격)
```

### 2. 즉시 동기화
```bash
# ExternalSecret 리소스를 다시 적용하여 즉시 동기화
kubectl apply -f k8s/external-secrets/external-secrets-operator.yaml
```

### 3. External Secrets Operator 업그레이드
```bash
# Helm 차트 업데이트
helm repo update
helm upgrade external-secrets external-secrets/external-secrets \
  --namespace external-secrets-system
```

## 참고 자료

- [External Secrets Operator 공식 문서](https://external-secrets.io/)
- [AWS Secrets Manager 사용자 가이드](https://docs.aws.amazon.com/secretsmanager/)
- [Kubernetes Secrets 관리 모범 사례](https://kubernetes.io/docs/concepts/configuration/secret/)
- [IRSA 설정 가이드](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)