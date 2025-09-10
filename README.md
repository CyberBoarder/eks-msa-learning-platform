# EKS MSA Learning Platform

AWS EKS 기반 마이크로서비스 아키텍처(MSA) 웹서비스 운영 및 트러블슈팅 학습을 위한 종합적인 플랫폼입니다.

## 🎯 프로젝트 개요

이 플랫폼은 SRE/인프라 엔지니어가 실제 운영 환경에서 발생할 수 있는 다양한 문제 상황을 경험하고, AWS 계층, Kubernetes 계층, 애플리케이션 계층의 문제를 식별하고 해결하는 능력을 기를 수 있도록 설계되었습니다.

## 🏗️ 아키텍처

### 마이크로서비스 구성
- **Frontend Service**: React.js 기반 웹 UI
- **Main Service**: Node.js 기반 API Gateway
- **Catalog Service**: Python FastAPI 기반 상품 카탈로그 서비스
- **Order Service**: Java Spring Boot 기반 주문 처리 서비스

### 인프라 구성
- **EKS 클러스터**: Kubernetes 오케스트레이션
- **RDS PostgreSQL**: 관계형 데이터베이스
- **ElastiCache Redis**: 캐싱 및 세션 스토리지
- **S3**: 파일 스토리지
- **EFS**: 공유 파일 시스템

## 📁 프로젝트 구조

```
eks-msa-learning-platform/
├── apps/                           # 마이크로서비스 애플리케이션
│   ├── frontend/                   # React 프론트엔드
│   ├── main-service/              # Node.js API Gateway
│   ├── catalog-service/           # Python FastAPI 카탈로그 서비스
│   └── order-service/             # Java Spring Boot 주문 서비스
├── terraform/                      # Infrastructure as Code
│   ├── modules/                   # Terraform 모듈
│   │   ├── vpc/                   # VPC 및 네트워킹
│   │   ├── eks/                   # EKS 클러스터
│   │   ├── rds/                   # RDS 데이터베이스
│   │   ├── elasticache/           # Redis 클러스터
│   │   ├── s3/                    # S3 버킷
│   │   ├── efs/                   # EFS 파일 시스템
│   │   └── ecr/                   # ECR 리포지토리
│   ├── main.tf                    # 메인 Terraform 설정
│   ├── variables.tf               # 변수 정의
│   └── outputs.tf                 # 출력 값
├── k8s/                           # Kubernetes 매니페스트
│   ├── deployments/               # 애플리케이션 Deployment
│   ├── services/                  # Service 및 ServiceMonitor
│   ├── config/                    # ConfigMap 설정
│   ├── secrets/                   # Secret 설정
│   ├── rbac/                      # RBAC 및 ServiceAccount
│   ├── security/                  # 보안 정책
│   ├── addons/                    # EKS 애드온
│   ├── external-secrets/          # External Secrets Operator
│   ├── autoscaling/               # HPA, PDB 설정
│   └── namespaces/                # 네임스페이스 정의
├── monitoring/                     # 모니터링 설정
│   └── prometheus/                # Prometheus 설정
├── scripts/                       # 자동화 스크립트
│   ├── setup.sh                   # 초기 설정 스크립트
│   ├── deploy-applications.sh     # 애플리케이션 배포 스크립트
│   ├── setup-secrets.sh           # Secret 설정 스크립트
│   ├── setup-rbac.sh              # RBAC 설정 스크립트
│   └── install-addons.sh          # 애드온 설치 스크립트
├── docs/                          # 문서
│   └── README.md                  # 상세 문서
├── .kiro/specs/                   # 프로젝트 스펙 (개발 과정)
│   └── eks-msa-learning-platform/
│       ├── requirements.md        # 요구사항 문서
│       ├── design.md              # 설계 문서
│       └── tasks.md               # 작업 목록
├── .gitignore                     # Git 무시 파일
├── .env.example                   # 환경 변수 예제
└── README.md                      # 이 파일
```

## 🚀 빠른 시작

### 1. 전제 조건

- AWS CLI 설치 및 구성
- kubectl 설치
- Terraform 설치
- Docker 설치

### 2. 인프라 배포

```bash
# Terraform으로 AWS 인프라 배포
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. 애플리케이션 배포

```bash
# 환경 변수 설정
export ECR_REGISTRY="your-account-id.dkr.ecr.region.amazonaws.com"
export AWS_ACCOUNT_ID="your-account-id"

# 애플리케이션 배포
./scripts/deploy-applications.sh
```

## 📚 학습 시나리오

### 시나리오 1: 기본 배포 및 모니터링
- EKS 클러스터 구축 및 기본 애플리케이션 배포
- Prometheus/Grafana 모니터링 설정
- 웹 애플리케이션 접근 및 메트릭 확인

### 시나리오 2: 오토스케일링 및 성능 테스트
- HPA 설정 및 부하 테스트
- k6를 통한 부하 테스트
- 스케일링 동작 관찰

### 시나리오 3: 장애 대응 및 복구
- Chaos Mesh를 통한 장애 주입
- 모니터링 알람 확인
- 수동/자동 복구 절차

### 시나리오 4: 보안 강화 및 컴플라이언스
- kube-bench 실행 및 결과 분석
- Falco 알람 설정
- Network Policy 적용

## 🔧 주요 기능

### 인프라 관리
- **Infrastructure as Code**: Terraform을 통한 완전 자동화된 인프라 구축
- **고가용성**: Multi-AZ 배포 및 자동 장애조치
- **보안**: IRSA, Network Policy, Pod Security Standards 적용

### 애플리케이션 운영
- **마이크로서비스**: 독립적인 서비스 배포 및 관리
- **컨테이너화**: Docker 기반 애플리케이션 패키징
- **오케스트레이션**: Kubernetes를 통한 자동화된 배포 및 관리

### 모니터링 및 관측성
- **메트릭 수집**: Prometheus를 통한 시스템 및 애플리케이션 메트릭
- **시각화**: Grafana 대시보드를 통한 실시간 모니터링
- **알람**: Alertmanager를 통한 장애 알림

### 보안 및 컴플라이언스
- **런타임 보안**: Falco를 통한 실시간 위협 탐지
- **컴플라이언스**: kube-bench를 통한 CIS 벤치마크 준수 확인
- **네트워크 보안**: Network Policy를 통한 트래픽 제어

### 카오스 엔지니어링
- **장애 시뮬레이션**: Chaos Mesh를 통한 다양한 장애 시나리오
- **복원력 테스트**: 시스템의 장애 대응 능력 검증
- **자동 복구**: 장애 발생 시 자동 복구 메커니즘

## 🛠️ 기술 스택

### 애플리케이션
- **Frontend**: React.js, TypeScript, Nginx
- **API Gateway**: Node.js, Express.js
- **Catalog Service**: Python, FastAPI, SQLAlchemy
- **Order Service**: Java, Spring Boot, JPA

### 인프라
- **Container Orchestration**: Kubernetes (EKS)
- **Infrastructure**: AWS (VPC, EKS, RDS, ElastiCache, S3, EFS)
- **Infrastructure as Code**: Terraform
- **Container Registry**: Amazon ECR

### 모니터링
- **Metrics**: Prometheus, Grafana
- **Logging**: Fluent Bit, CloudWatch Logs
- **Tracing**: (향후 Jaeger 추가 예정)

### 보안
- **Runtime Security**: Falco
- **Compliance**: kube-bench
- **Network Security**: Calico Network Policies
- **Secrets Management**: AWS Secrets Manager, External Secrets Operator

### CI/CD
- **Source Control**: GitHub
- **CI/CD**: GitHub Actions
- **GitOps**: ArgoCD (향후 추가 예정)

## 📖 문서

- [요구사항 문서](.kiro/specs/eks-msa-learning-platform/requirements.md)
- [설계 문서](.kiro/specs/eks-msa-learning-platform/design.md)
- [작업 목록](.kiro/specs/eks-msa-learning-platform/tasks.md)
- [배포 가이드](k8s/deployments/README.md)
- [상세 문서](docs/README.md)

## 🤝 기여하기

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

## 📞 지원

문제가 발생하거나 질문이 있으시면 [Issues](https://github.com/CyberBoarder/eks-msa-learning-platform/issues)를 통해 문의해주세요.

## 🙏 감사의 말

이 프로젝트는 실제 운영 환경에서의 경험을 바탕으로 만들어졌으며, 많은 오픈소스 프로젝트들의 도움을 받았습니다.

---

**EKS MSA Learning Platform** - AWS EKS 기반 마이크로서비스 운영 학습을 위한 종합 플랫폼