# Implementation Plan

- [x] 1. 프로젝트 구조 및 기본 설정 구성
  - 프로젝트 루트 디렉토리 구조 생성 (terraform/, k8s/, apps/, monitoring/, docs/)
  - 각 마이크로서비스별 디렉토리 구조 설정
  - 공통 설정 파일 및 환경 변수 템플릿 생성
  - _Requirements: 1.1, 2.1_

- [x] 2. Terraform 인프라 코드 구현
- [x] 2.1 VPC 및 네트워크 리소스 생성
  - VPC, 서브넷(퍼블릭/프라이빗), 인터넷 게이트웨이, NAT 게이트웨이 정의
  - 보안 그룹 및 NACL 설정
  - Route 테이블 구성
  - _Requirements: 1.1_

- [x] 2.2 EKS 클러스터 및 노드 그룹 생성
  - EKS 클러스터 리소스 정의 (버전 1.28+)
  - 시스템 노드 그룹 (t3.medium) 및 애플리케이션 노드 그룹 (t3.large) 구성
  - IRSA 설정 및 필요한 IAM 역할 생성
  - _Requirements: 1.1, 1.2_

- [x] 2.3 RDS PostgreSQL 및 ElastiCache Redis 구성
  - Multi-AZ RDS PostgreSQL 인스턴스 생성
  - ElastiCache Redis 클러스터 구성
  - 데이터베이스 서브넷 그룹 및 보안 그룹 설정
  - _Requirements: 3.1, 3.4_

- [x] 2.4 S3, EFS 및 기타 AWS 서비스 구성
  - S3 버킷 생성 및 정책 설정
  - EFS 파일 시스템 및 마운트 타겟 구성
  - ECR 리포지토리 생성
  - _Requirements: 3.3, 3.5_

- [x] 3. Kubernetes 기본 구성 요소 배포
- [x] 3.1 필수 Kubernetes 애드온 설치
  - AWS Load Balancer Controller 설치 및 구성
  - EBS CSI Driver, EFS CSI Driver 설치
  - Metrics Server 설치
  - _Requirements: 1.3, 1.4_

- [x] 3.2 네임스페이스 및 RBAC 설정
  - 애플리케이션별 네임스페이스 생성 (frontend, backend, monitoring, security, chaos)
  - ServiceAccount 및 RBAC 정책 설정
  - Network Policy 기본 규칙 적용
  - _Requirements: 8.3_

- [x] 3.3 Secrets 및 ConfigMap 관리
  - 데이터베이스 연결 정보를 위한 Secret 생성
  - 애플리케이션 설정을 위한 ConfigMap 생성
  - External Secrets Operator 설치 및 구성
  - _Requirements: 3.2_

- [x] 4. 마이크로서비스 애플리케이션 개발
- [x] 4.1 Frontend 서비스 구현
  - React 컴포넌트 및 페이지 구현 (Layout, Dashboard, ProductCatalog, OrderManagement, FileUpload)
  - API 클라이언트 서비스 구현 (axios 기반)
  - 상품 카탈로그 조회 및 관리 UI 구현
  - 주문 생성 및 조회 UI 구현
  - 파일 업로드 기능 및 S3 연동 구현
  - 실시간 모니터링 대시보드 구현
  - Dockerfile 및 nginx 설정 작성
  - _Requirements: 2.1_

- [x] 4.2 Main Service (API Gateway) 구현
  - Express.js 서버 및 미들웨어 설정 구현 (src/index.js)
  - 헬스체크 및 메트릭 엔드포인트 구현
  - 카탈로그 서비스 프록시 API 구현
  - 주문 서비스 프록시 API 구현
  - S3 파일 업로드 API 구현 (multer-s3 사용)
  - Circuit Breaker 패턴 및 에러 핸들링 구현
  - Redis 연결 및 세션 관리 구현
  - Dockerfile 및 헬스체크 설정 작성
  - _Requirements: 2.2, 2.5_

- [x] 4.3 Catalog Service 구현
  - FastAPI 애플리케이션 및 라우터 구현 (src/main.py)
  - PostgreSQL 연결 및 SQLAlchemy 모델 정의
  - 상품 CRUD API 엔드포인트 구현 (/products, /categories)
  - Redis 캐싱 레이어 구현 (상품 조회 성능 최적화)
  - 데이터베이스 마이그레이션 스크립트 작성 (Alembic)
  - Prometheus 메트릭 수집 구현
  - 비동기 처리 및 에러 핸들링 구현
  - Dockerfile 및 헬스체크 설정 작성
  - _Requirements: 2.3, 3.2, 3.4_

- [x] 4.4 Order Service 구현 완료
- [x] 4.4.1 Order Service 컨트롤러 및 서비스 레이어 구현
  - OrderController 클래스 구현 (주문 CRUD API 엔드포인트)
  - OrderService 비즈니스 로직 구현
  - OrderItemService 주문 상품 관리 로직 구현
  - 주문 상태 변경 및 히스토리 관리 구현
  - _Requirements: 2.4_

- [x] 4.4.2 Order Service Redis 메시징 및 트랜잭션 구현
  - Redis Pub/Sub 메시징 구현 (주문 상태 알림)
  - 트랜잭션 관리 및 데이터 일관성 보장
  - Actuator 및 Prometheus 메트릭 설정
  - 단위 테스트 및 통합 테스트 작성
  - _Requirements: 2.4, 3.2, 3.4_

- [x] 5. 컨테이너 이미지 빌드 및 레지스트리 설정
- [x] 5.1 각 서비스별 Dockerfile 최적화
  - Multi-stage 빌드를 통한 이미지 크기 최적화
  - 보안 취약점 최소화를 위한 베이스 이미지 선택 (distroless, alpine)
  - 헬스체크 및 시그널 처리 구현
  - 각 서비스 디렉토리에 Dockerfile 작성
  - _Requirements: 7.2_

- [x] 5.2 CI/CD 파이프라인 구성
  - .github/workflows/ 디렉토리 생성 및 GitHub Actions 워크플로우 작성
  - 코드 품질 검사 (ESLint, SonarQube) 단계 추가
  - 단위 테스트 실행 단계 구성
  - ECR 이미지 빌드 및 푸시 단계 구현
  - 보안 스캔 (Trivy) 단계 추가
  - _Requirements: 7.1, 7.2_

- [ ] 6. Kubernetes 애플리케이션 배포 매니페스트 작성
- [ ] 6.1 애플리케이션 Deployment 및 Service 매니페스트 작성
  - Frontend 서비스 Deployment 및 Service 매니페스트 작성 (k8s/deployments/frontend-deployment.yaml, k8s/services/frontend-service.yaml)
  - Main Service Deployment 및 Service 매니페스트 작성 (k8s/deployments/main-service-deployment.yaml, k8s/services/main-service-service.yaml)
  - Catalog Service Deployment 및 Service 매니페스트 작성 (k8s/deployments/catalog-service-deployment.yaml, k8s/services/catalog-service-service.yaml)
  - Order Service Deployment 및 Service 매니페스트 작성 (k8s/deployments/order-service-deployment.yaml, k8s/services/order-service-service.yaml)
  - ConfigMap 및 Secret 마운트 설정 (기존 ConfigMap 활용)
  - Liveness/Readiness Probe 구성 (각 서비스의 헬스체크 엔드포인트 활용)
  - 리소스 요청 및 제한 설정 (CPU/Memory)
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 6.2 Ingress 및 라우팅 구성
  - ALB Ingress Controller를 위한 Ingress 리소스 작성 (k8s/ingress/main-ingress.yaml)
  - 서비스별 라우팅 규칙 정의 (/, /api, /catalog, /orders)
  - SSL/TLS 인증서 설정 (AWS Certificate Manager 연동)
  - 헬스체크 및 로드밸런싱 설정
  - _Requirements: 1.3, 2.5_

- [ ] 6.3 HPA 및 PDB 설정
  - 각 서비스별 Horizontal Pod Autoscaler 정책 정의 (k8s/autoscaling/hpa.yaml)
  - CPU/Memory 기반 스케일링 규칙 구성
  - Pod Disruption Budget 설정 (k8s/autoscaling/pdb.yaml)
  - VPA(Vertical Pod Autoscaler) 설정 (k8s/autoscaling/vpa.yaml)
  - _Requirements: 5.1, 5.2_

- [ ] 7. 모니터링 및 관측성 구현
- [ ] 7.1 Prometheus 스택 배포 및 설정
  - kube-prometheus-stack Helm 차트를 사용한 Prometheus Operator 설치 스크립트 작성
  - 기존 monitoring/prometheus/values.yaml 파일을 기반으로 Prometheus, Grafana, Alertmanager 구성 업데이트
  - 각 마이크로서비스별 ServiceMonitor 및 PodMonitor 리소스 작성 (monitoring/servicemonitors/)
  - Node Exporter 및 kube-state-metrics 설치 확인 스크립트 작성
  - monitoring 네임스페이스에 모니터링 스택 배포 스크립트 작성
  - _Requirements: 4.1, 4.2_

- [ ] 7.2 Grafana 대시보드 및 알람 구성
  - 애플리케이션 메트릭 대시보드 JSON 파일 생성 (monitoring/grafana/dashboards/application-metrics.json)
  - 인프라 메트릭 대시보드 생성 (monitoring/grafana/dashboards/infrastructure-metrics.json)
  - SLI/SLO 모니터링 대시보드 구성 (monitoring/grafana/dashboards/sli-slo-dashboard.json)
  - Alertmanager 알람 규칙 작성 (monitoring/prometheus/alert-rules.yaml)
  - Slack 연동 설정 (기존 Secret 활용)
  - _Requirements: 4.2, 4.4_

- [ ] 7.3 로그 수집 및 분석 시스템 구성
  - Fluent Bit DaemonSet 배포 매니페스트 작성 (k8s/logging/fluent-bit-daemonset.yaml)
  - CloudWatch Logs 연동 설정 (k8s/logging/fluent-bit-configmap.yaml)
  - 로그 파싱 및 필터링 규칙 구성
  - 로그 기반 알람 설정 (k8s/logging/log-based-alarms.yaml)
  - _Requirements: 4.5_

- [ ] 8. 보안 도구 및 컴플라이언스 구현
- [ ] 8.1 Falco 런타임 보안 모니터링 설치
  - Falco Helm 차트를 사용한 DaemonSet 배포 스크립트 작성 (scripts/install-falco.sh)
  - 커스텀 보안 규칙 작성 (k8s/security/falco/custom-rules.yaml)
  - 보안 이벤트 알림 설정 (k8s/security/falco/falco-config.yaml)
  - CloudWatch와 연동하여 보안 로그 수집 설정
  - _Requirements: 8.2_

- [ ] 8.2 kube-bench CIS 벤치마크 자동화
  - kube-bench CronJob 배포 매니페스트 작성 (k8s/security/kube-bench/kube-bench-cronjob.yaml)
  - 벤치마크 결과를 S3에 저장하는 스크립트 작성 (scripts/kube-bench-s3-upload.sh)
  - 컴플라이언스 점수 모니터링 대시보드 구성 (monitoring/grafana/dashboards/compliance-dashboard.json)
  - 벤치마크 실패 시 알람 설정 (monitoring/prometheus/kube-bench-alerts.yaml)
  - _Requirements: 8.1_

- [ ] 8.3 이미지 보안 스캔 자동화
  - ECR 이미지 스캔 활성화 (terraform/modules/ecr/main.tf 업데이트)
  - CI/CD 파이프라인에 Trivy 보안 스캔 단계 추가 (.github/workflows/security-scan.yml)
  - 취약점 발견 시 배포 중단 로직 구현
  - 보안 스캔 결과 리포팅 자동화 (scripts/security-report.sh)
  - _Requirements: 8.4_

- [ ] 9. 카오스 엔지니어링 및 장애 테스트 구현
- [ ] 9.1 Chaos Mesh 설치 및 기본 실험 구성
  - Chaos Mesh Helm 차트를 사용한 Operator 설치 스크립트 작성 (scripts/install-chaos-mesh.sh)
  - Pod 장애 실험 시나리오 YAML 작성 (chaos-engineering/experiments/pod-failure.yaml)
  - 네트워크 지연 및 파티션 실험 구성 (chaos-engineering/experiments/network-chaos.yaml)
  - CPU/메모리 스트레스 테스트 시나리오 작성 (chaos-engineering/experiments/stress-test.yaml)
  - 실험 실행 및 관리 스크립트 작성 (chaos-engineering/scripts/run-experiments.sh)
  - _Requirements: 6.1_

- [ ] 9.2 장애 복구 자동화 및 모니터링
  - 장애 실험 중 메트릭 수집 자동화 스크립트 작성 (chaos-engineering/scripts/collect-metrics.sh)
  - 복구 시간 측정 및 리포팅 스크립트 작성 (chaos-engineering/scripts/recovery-report.sh)
  - 장애 실험 결과 분석 Grafana 대시보드 구성 (monitoring/grafana/dashboards/chaos-engineering.json)
  - 자동 롤백 메커니즘 구현 (chaos-engineering/scripts/auto-rollback.sh)
  - _Requirements: 6.2, 6.3_

- [ ] 10. 성능 테스트 및 부하 테스트 구현
- [ ] 10.1 k6 성능 테스트 스크립트 작성
  - 정상 부하 테스트 시나리오 JavaScript 스크립트 구현 (performance-tests/load-test.js)
  - 스파이크 테스트 시나리오 구현 (performance-tests/spike-test.js)
  - 내구성 테스트 시나리오 구현 (performance-tests/endurance-test.js)
  - 성능 테스트 결과 분석 스크립트 작성 (performance-tests/analyze-results.js)
  - 테스트 실행 자동화 스크립트 작성 (performance-tests/run-tests.sh)
  - _Requirements: 5.4_

- [ ] 10.2 오토스케일링 검증 테스트
  - HPA 동작 검증을 위한 부하 테스트 실행 스크립트 작성 (performance-tests/hpa-validation.sh)
  - 스케일링 메트릭 수집 및 분석 스크립트 작성 (performance-tests/scaling-metrics.sh)
  - 스케일링 성능 최적화 가이드 작성 (docs/scaling-optimization.md)
  - 스케일링 이벤트 알림 설정 (monitoring/prometheus/scaling-alerts.yaml)
  - _Requirements: 5.1, 5.2, 5.3_

- [ ] 11. GitOps 및 배포 자동화 구현
- [ ] 11.1 ArgoCD 설치 및 구성
  - ArgoCD Helm 차트를 사용한 서버 및 컨트롤러 배포 스크립트 작성 (scripts/install-argocd.sh)
  - Git 리포지토리 연동 설정 (gitops/argocd/repository-config.yaml)
  - 각 마이크로서비스별 ArgoCD Application 리소스 작성 (gitops/argocd/applications/)
  - 자동 동기화 및 Self-healing 설정 (gitops/argocd/app-of-apps.yaml)
  - ArgoCD 접근을 위한 Ingress 설정 (gitops/argocd/argocd-ingress.yaml)
  - _Requirements: 7.3_

- [ ] 11.2 Blue-Green 및 Canary 배포 전략 구현
  - Argo Rollouts 설치 및 구성 스크립트 작성 (scripts/install-argo-rollouts.sh)
  - Blue-Green 배포 전략 Rollout 리소스 작성 (gitops/rollouts/blue-green-rollout.yaml)
  - Canary 배포 전략 및 트래픽 분할 설정 (gitops/rollouts/canary-rollout.yaml)
  - 배포 실패 시 자동 롤백 구성 (gitops/rollouts/rollback-config.yaml)
  - 배포 전략 테스트 스크립트 작성 (gitops/rollouts/test-deployment.sh)
  - _Requirements: 7.4_

- [x] 12. 데이터베이스 초기화 및 데이터 설정
- [x] 12.1 데이터베이스 스키마 및 초기 데이터 설정
  - Catalog Service Alembic 마이그레이션 실행 및 검증 (기존 마이그레이션 파일 활용)
  - 상품 카테고리 및 샘플 상품 데이터 삽입 스크립트 작성
  - 테스트용 주문 데이터 생성 스크립트 작성
  - Kubernetes Job을 사용한 데이터베이스 초기화 매니페스트 작성
  - 데이터베이스 마이그레이션 및 시드 데이터 관리 스크립트 구현
  - database/ 디렉토리에 스키마, 마이그레이션, 시드 파일 생성
  - _Requirements: 3.1, 3.2_

- [x] 12.2 Redis 설정 및 캐시 전략 검증
  - 기존 Redis 연결 설정 검증 및 최적화
  - 상품 정보 캐싱 전략 및 TTL 설정 테스트
  - 세션 스토리지 및 사용자 상태 관리 검증
  - Pub/Sub 메시징 채널 설정 및 테스트 (주문 상태 알림)
  - Redis 성능 모니터링 및 메트릭 수집 설정
  - _Requirements: 3.4_

- [x] 13. 통합 테스트 및 E2E 테스트 구현
- [x] 13.1 API 통합 테스트 확장 및 완성
  - 기존 테스트 파일들을 확장하여 서비스 간 통신 테스트 구현
  - 데이터베이스 CRUD 연동 테스트 작성 (기존 테스트 확장)
  - Redis 캐싱 동작 검증 테스트 구현
  - S3 파일 업로드/다운로드 기능 테스트 작성
  - API 에러 핸들링 및 복구 테스트 구현
  - 서비스 디스커버리 및 로드밸런싱 테스트 작성
  - tests/integration/ 디렉토리에 통합 테스트 파일 생성
  - _Requirements: 2.5_

- [ ] 13.2 End-to-End 테스트 자동화
  - Cypress를 사용한 웹 UI 테스트 작성 (tests/e2e/cypress/integration/)
  - 사용자 워크플로우 테스트 구현 (tests/e2e/cypress/integration/user-workflow.spec.js)
  - 파일 업로드 및 다운로드 E2E 테스트 구현 (tests/e2e/cypress/integration/file-upload.spec.js)
  - 모니터링 대시보드 기능 테스트 작성 (tests/e2e/cypress/integration/dashboard.spec.js)
  - 테스트 데이터 셋업/정리 자동화 스크립트 구현 (tests/e2e/scripts/setup-test-data.sh)
  - CI/CD 파이프라인에 E2E 테스트 통합 (.github/workflows/e2e-tests.yml)
  - Cypress 설정 파일 작성 (tests/e2e/cypress.config.js)
  - _Requirements: 2.1, 2.2, 2.3, 2.4_

- [ ] 14. 문서화 및 학습 자료 작성
- [ ] 14.1 운영 가이드 및 런북 작성
  - 시스템 아키텍처 문서 작성 (docs/architecture/system-overview.md, docs/architecture/network-diagram.md)
  - 배포 및 운영 절차 가이드 작성 (docs/operations/deployment-guide.md, docs/operations/maintenance-procedures.md)
  - 트러블슈팅 가이드 및 FAQ 작성 (docs/troubleshooting/common-issues.md, docs/troubleshooting/faq.md)
  - 장애 대응 런북 작성 (docs/runbooks/incident-response.md, docs/runbooks/service-recovery.md)
  - _Requirements: 9.3_

- [ ] 14.2 학습 시나리오 및 실습 가이드 작성
  - 단계별 학습 모듈 구성 (docs/learning-scenarios/module-01-basic-deployment.md ~ module-04-advanced-operations.md)
  - 각 시나리오별 실습 가이드 작성 (docs/learning-scenarios/hands-on-labs/)
  - 검증 방법 및 예상 결과 문서화 (docs/learning-scenarios/validation-guides/)
  - 성취도 평가 기준 및 추가 학습 자료 제공 (docs/learning-scenarios/assessment-criteria.md)
  - _Requirements: 10.1, 10.2, 10.3, 10.4_

- [ ] 15. GitHub Issue 템플릿 및 자동화 구성
- [ ] 15.1 장애 대응 Issue 템플릿 작성
  - GitHub Issue 템플릿 파일 생성 (.github/ISSUE_TEMPLATE/incident-report.yml, .github/ISSUE_TEMPLATE/bug-report.yml)
  - 증상, 원인, 조치사항 템플릿 구성 (.github/ISSUE_TEMPLATE/postmortem.yml)
  - 장애 분류 라벨 시스템 구현 (.github/labels.yml)
  - 자동 할당 및 에스컬레이션 규칙 설정 (.github/workflows/issue-automation.yml)
  - 포스트모템 템플릿 작성 (.github/ISSUE_TEMPLATE/postmortem-template.md)
  - _Requirements: 9.1, 9.4_

- [ ] 15.2 모니터링 알람과 Issue 생성 자동화
  - 알람 발생 시 자동 Issue 생성 웹훅 구현 (automation/webhook-handler.js)
  - 알람 심각도별 Issue 우선순위 설정 (automation/priority-mapper.js)
  - 관련 메트릭 및 로그 자동 첨부 스크립트 작성 (automation/log-collector.sh)
  - 해결 시 Issue 자동 종료 로직 구현 (automation/issue-closer.js)
  - 자동화 배포 스크립트 작성 (automation/deploy-automation.sh)
  - _Requirements: 9.2_

- [ ] 16. 최종 통합 테스트 및 검증
- [ ] 16.1 전체 시스템 통합 테스트 및 배포 검증
  - 모든 컴포넌트 간 연동 테스트 실행 스크립트 작성 (tests/integration/full-system-test.sh)
  - Kubernetes 배포 매니페스트 적용 및 검증 스크립트 작성 (scripts/validate-deployment.sh)
  - 성능 및 안정성 검증 테스트 실행 (tests/integration/performance-validation.sh)
  - 보안 설정 및 컴플라이언스 검증 스크립트 작성 (tests/security/compliance-check.sh)
  - 장애 복구 시나리오 테스트 실행 (tests/chaos/disaster-recovery-test.sh)
  - 모니터링 및 알람 동작 검증 스크립트 작성 (tests/monitoring/alert-validation.sh)
  - _Requirements: 모든 요구사항_

- [ ] 16.2 학습 환경 최종 설정 및 문서 정리
  - 학습자용 환경 설정 가이드 작성 (docs/setup/learner-environment-setup.md)
  - 리소스 정리 및 비용 최적화 가이드 작성 (docs/operations/cost-optimization.md)
  - 전체 시스템 데모 시나리오 준비 (docs/demo/system-demo-script.md)
  - 피드백 수집 및 개선사항 반영 프로세스 문서화 (docs/feedback/improvement-process.md)
  - 배포 및 운영 가이드 최종 검토 및 업데이트 (docs/operations/final-deployment-guide.md)
  - _Requirements: 10.1, 10.2, 10.3, 10.4_