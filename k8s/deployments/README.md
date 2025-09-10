# Kubernetes 애플리케이션 배포 가이드

이 디렉토리는 EKS MSA Learning Platform의 모든 마이크로서비스를 위한 Kubernetes Deployment 매니페스트를 포함합니다.

## 📁 파일 구조

```
k8s/
├── deployments/
│   ├── frontend-deployment.yaml          # React 프론트엔드 서비스
│   ├── main-service-deployment.yaml      # Node.js API Gateway
│   ├── catalog-service-deployment.yaml   # Python FastAPI 카탈로그 서비스
│   ├── order-service-deployment.yaml     # Java Spring Boot 주문 서비스
│   └── README.md                         # 이 파일
├── services/
│   ├── frontend-service.yaml             # Frontend Service 및 ServiceMonitor
│   ├── main-service-service.yaml         # Main Service 및 ServiceMonitor
│   ├── catalog-service-service.yaml      # Catalog Service 및 ServiceMonitor
│   └── order-service-service.yaml        # Order Service 및 ServiceMonitor
├── rbac/
│   └── application-service-accounts.yaml # ServiceAccount 및 RBAC 설정
└── autoscaling/
    └── pod-disruption-budgets.yaml       # Pod Disruption Budget 설정
```

## 🚀 배포 방법

### 1. 전제 조건

배포하기 전에 다음 사항들이 준비되어 있어야 합니다:

- EKS 클러스터가 생성되어 있어야 함
- kubectl이 클러스터에 연결되어 있어야 함
- ECR 리포지토리에 애플리케이션 이미지가 푸시되어 있어야 함
- 필요한 Secret들이 생성되어 있어야 함

### 2. 환경 변수 설정

```bash
export ECR_REGISTRY="123456789012.dkr.ecr.ap-northeast-1.amazonaws.com"
export AWS_ACCOUNT_ID="123456789012"
```

### 3. 자동 배포 (권장)

```bash
# 전체 애플리케이션 자동 배포
./scripts/deploy-applications.sh
```

### 4. 수동 배포

단계별로 수동 배포하려면:

```bash
# 1. 네임스페이스 생성
kubectl apply -f k8s/namespaces/namespaces.yaml

# 2. ConfigMap 배포
kubectl apply -f k8s/config/configmaps.yaml

# 3. RBAC 설정 배포
envsubst < k8s/rbac/application-service-accounts.yaml | kubectl apply -f -

# 4. 애플리케이션 배포 (순서 중요)
envsubst < k8s/deployments/catalog-service-deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/services/catalog-service-service.yaml

envsubst < k8s/deployments/order-service-deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/services/order-service-service.yaml

envsubst < k8s/deployments/main-service-deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/services/main-service-service.yaml

envsubst < k8s/deployments/frontend-deployment.yaml | kubectl apply -f -
kubectl apply -f k8s/services/frontend-service.yaml

# 5. PDB 배포
kubectl apply -f k8s/autoscaling/pod-disruption-budgets.yaml
```

## 🔍 배포 상태 확인

### Pod 상태 확인
```bash
kubectl get pods -n frontend
kubectl get pods -n backend
```

### Service 상태 확인
```bash
kubectl get svc -n frontend
kubectl get svc -n backend
```

### 배포 상태 확인
```bash
kubectl rollout status deployment/frontend -n frontend
kubectl rollout status deployment/main-service -n backend
kubectl rollout status deployment/catalog-service -n backend
kubectl rollout status deployment/order-service -n backend
```

### 로그 확인
```bash
# 특정 서비스 로그 확인
kubectl logs -f deployment/main-service -n backend

# 모든 Pod 로그 확인
kubectl logs -f -l app.kubernetes.io/part-of=eks-msa-learning -n backend
```

## 🏥 헬스체크

각 서비스는 다음 헬스체크 엔드포인트를 제공합니다:

- **Frontend**: `GET /health`
- **Main Service**: `GET /health`, `GET /health/ready`
- **Catalog Service**: `GET /health`, `GET /health/ready`
- **Order Service**: `GET /actuator/health`, `GET /actuator/health/liveness`, `GET /actuator/health/readiness`

### 헬스체크 테스트
```bash
# 포트 포워딩을 통한 헬스체크
kubectl port-forward -n backend svc/main-service 3001:3001 &
curl http://localhost:3001/health

kubectl port-forward -n backend svc/catalog-service 8000:8000 &
curl http://localhost:8000/health

kubectl port-forward -n backend svc/order-service 8080:8080 &
curl http://localhost:8080/actuator/health
```

## 📊 모니터링

각 서비스는 Prometheus 메트릭을 제공합니다:

- **Main Service**: `http://main-service:9090/metrics`
- **Catalog Service**: `http://catalog-service:9090/metrics`
- **Order Service**: `http://order-service:8081/actuator/prometheus`

ServiceMonitor 리소스가 자동으로 생성되어 Prometheus가 메트릭을 수집합니다.

## 🔧 트러블슈팅

### 일반적인 문제들

1. **Pod가 Pending 상태인 경우**
   ```bash
   kubectl describe pod <pod-name> -n <namespace>
   ```
   - 리소스 부족 확인
   - 노드 셀렉터 확인
   - PVC 마운트 문제 확인

2. **Pod가 CrashLoopBackOff 상태인 경우**
   ```bash
   kubectl logs <pod-name> -n <namespace> --previous
   ```
   - 애플리케이션 로그 확인
   - 환경 변수 설정 확인
   - 의존성 서비스 상태 확인

3. **Service 연결 문제**
   ```bash
   kubectl get endpoints -n <namespace>
   ```
   - 엔드포인트 확인
   - 셀렉터 라벨 매칭 확인
   - 네트워크 정책 확인

### 디버깅 명령어

```bash
# Pod 상세 정보
kubectl describe pod <pod-name> -n <namespace>

# 이벤트 확인
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# 리소스 사용량 확인
kubectl top pods -n <namespace>

# 네트워크 연결 테스트
kubectl exec -it <pod-name> -n <namespace> -- nslookup <service-name>
```

## 🔄 업데이트 및 롤백

### 이미지 업데이트
```bash
# 새 이미지로 업데이트
kubectl set image deployment/main-service main-service=${ECR_REGISTRY}/eks-msa-learning/main-service:v2.0.0 -n backend

# 롤아웃 상태 확인
kubectl rollout status deployment/main-service -n backend
```

### 롤백
```bash
# 이전 버전으로 롤백
kubectl rollout undo deployment/main-service -n backend

# 특정 리비전으로 롤백
kubectl rollout undo deployment/main-service --to-revision=2 -n backend
```

## 🧹 정리

배포된 리소스를 정리하려면:

```bash
# 애플리케이션 삭제
kubectl delete -f k8s/deployments/
kubectl delete -f k8s/services/
kubectl delete -f k8s/autoscaling/pod-disruption-budgets.yaml
kubectl delete -f k8s/rbac/application-service-accounts.yaml

# 네임스페이스 삭제 (주의: 모든 리소스가 삭제됨)
kubectl delete namespace frontend backend
```

## 📚 추가 리소스

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [EKS 사용자 가이드](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)