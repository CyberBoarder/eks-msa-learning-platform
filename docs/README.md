# EKS MSA Learning Platform

AWS EKS 기반 마이크로서비스 아키텍처 웹서비스 운영 및 트러블슈팅 학습을 위한 종합 플랫폼입니다.

## 프로젝트 구조

```
├── terraform/          # Infrastructure as Code
├── k8s/                # Kubernetes 매니페스트
├── apps/               # 마이크로서비스 애플리케이션
├── monitoring/         # 모니터링 설정
├── docs/              # 문서
└── scripts/           # 유틸리티 스크립트
```

## 시작하기

### 1. 사전 요구사항
- AWS CLI 설정
- Terraform >= 1.0
- kubectl
- Docker
- Helm

### 2. 인프라 배포
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 3. kubectl 설정
```bash
aws eks --region ap-northeast-1 update-kubeconfig --name eks-msa-learning-dev
```

## 아키텍처

- **Frontend**: React.js + TypeScript
- **Main Service**: Node.js + Express (API Gateway)
- **Catalog Service**: Python + FastAPI
- **Order Service**: Java + Spring Boot
- **Database**: PostgreSQL (RDS)
- **Cache**: Redis (ElastiCache)
- **Storage**: S3, EFS
- **Monitoring**: Prometheus + Grafana
- **Security**: Falco, kube-bench

## 학습 목표

1. EKS 클러스터 운영
2. MSA 패턴 이해
3. 모니터링 및 관측성
4. 장애 대응 및 트러블슈팅
5. 보안 및 컴플라이언스