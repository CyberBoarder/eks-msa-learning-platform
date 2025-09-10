# EKS 필수 애드온 설치 가이드

이 디렉토리에는 EKS 클러스터에 필요한 필수 애드온들의 매니페스트 파일들이 포함되어 있습니다.

## 포함된 애드온

### 1. AWS Load Balancer Controller
- **파일**: `aws-load-balancer-controller.yaml`
- **목적**: ALB/NLB 자동 생성 및 관리
- **기능**: 
  - Ingress 리소스를 통한 ALB 생성
  - Service 리소스를 통한 NLB 생성
  - WAF, Shield 통합 지원

### 2. EBS CSI Driver
- **파일**: `ebs-csi-driver.yaml`
- **목적**: EBS 볼륨을 통한 영구 스토리지 제공
- **기능**:
  - 동적 볼륨 프로비저닝
  - 볼륨 스냅샷 지원
  - 볼륨 확장 지원
  - 다양한 EBS 볼륨 타입 지원 (gp3, io2)

### 3. EFS CSI Driver
- **파일**: `efs-csi-driver.yaml`
- **목적**: EFS를 통한 공유 파일 시스템 제공
- **기능**:
  - ReadWriteMany 액세스 모드 지원
  - 동적/정적 프로비저닝
  - 액세스 포인트 기반 격리

### 4. Metrics Server
- **파일**: `metrics-server.yaml`
- **목적**: 리소스 메트릭 수집 및 HPA 지원
- **기능**:
  - CPU/메모리 사용률 수집
  - HPA 및 VPA 지원
  - kubectl top 명령어 지원

### 5. Cluster Autoscaler
- **파일**: `cluster-autoscaler.yaml`
- **목적**: 노드 자동 확장/축소
- **기능**:
  - 리소스 부족 시 노드 자동 추가
  - 유휴 노드 자동 제거
  - 다양한 확장 전략 지원

## 설치 방법

### 자동 설치 (권장)
```bash
# 환경 변수 설정
export CLUSTER_NAME="eks-msa-learning-dev"
export AWS_REGION="ap-northeast-1"
export VPC_ID="vpc-xxxxxxxxx"
export AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN="arn:aws:iam::account:role/..."
export EBS_CSI_DRIVER_ROLE_ARN="arn:aws:iam::account:role/..."
export EFS_CSI_DRIVER_ROLE_ARN="arn:aws:iam::account:role/..."
export CLUSTER_AUTOSCALER_ROLE_ARN="arn:aws:iam::account:role/..."
export EFS_FILE_SYSTEM_ID="fs-xxxxxxxxx"
export EFS_APP_DATA_ACCESS_POINT_ID="fsap-xxxxxxxxx"
export EFS_SHARED_CONFIG_ACCESS_POINT_ID="fsap-xxxxxxxxx"
export EFS_LOGS_ACCESS_POINT_ID="fsap-xxxxxxxxx"

# 설치 스크립트 실행
./scripts/install-addons.sh
```

### 수동 설치
각 애드온을 개별적으로 설치할 수 있습니다:

```bash
# 1. 네임스페이스 생성
kubectl apply -f k8s/namespaces/namespaces.yaml

# 2. Metrics Server 설치
kubectl apply -f k8s/addons/metrics-server.yaml

# 3. AWS Load Balancer Controller 설치
helm repo add eks https://aws.github.io/eks-charts
helm repo update
kubectl apply -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$CLUSTER_NAME \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$AWS_LOAD_BALANCER_CONTROLLER_ROLE_ARN

# 4. EBS CSI Driver 설치 (EKS 애드온)
aws eks create-addon \
  --cluster-name $CLUSTER_NAME \
  --addon-name aws-ebs-csi-driver \
  --service-account-role-arn $EBS_CSI_DRIVER_ROLE_ARN

# 5. EFS CSI Driver 설치
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm install aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
  -n kube-system \
  --set controller.serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=$EFS_CSI_DRIVER_ROLE_ARN

# 6. Cluster Autoscaler 설치
envsubst < k8s/addons/cluster-autoscaler.yaml | kubectl apply -f -
```

## 설치 확인

```bash
# Pod 상태 확인
kubectl get pods -n kube-system

# StorageClass 확인
kubectl get storageclass

# Metrics Server 동작 확인
kubectl top nodes
kubectl top pods -A

# 네임스페이스 확인
kubectl get namespaces
```

## 트러블슈팅

### AWS Load Balancer Controller
- IRSA 역할이 올바르게 설정되었는지 확인
- VPC ID와 서브넷 태그가 올바른지 확인
- 보안 그룹 설정 확인

### EBS CSI Driver
- EKS 애드온 상태 확인: `aws eks describe-addon --cluster-name $CLUSTER_NAME --addon-name aws-ebs-csi-driver`
- IAM 역할 권한 확인

### EFS CSI Driver
- EFS 파일 시스템이 존재하는지 확인
- 마운트 타겟이 올바른 서브넷에 생성되었는지 확인
- 보안 그룹에서 NFS 포트(2049) 허용 확인

### Metrics Server
- kubelet 인증서 문제 시 `--kubelet-insecure-tls` 플래그 확인
- 네트워크 정책으로 인한 통신 차단 확인

### Cluster Autoscaler
- 노드 그룹에 올바른 태그가 설정되었는지 확인
- IAM 역할에 Auto Scaling 권한이 있는지 확인

## 참고 자료

- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [EFS CSI Driver](https://github.com/kubernetes-sigs/aws-efs-csi-driver)
- [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)