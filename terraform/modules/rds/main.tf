# RDS PostgreSQL Module for MSA Learning Platform
# Multi-AZ 구성으로 고가용성 보장

# DB 서브넷 그룹 생성
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  })
}

# DB 파라미터 그룹 생성 (PostgreSQL 최적화)
resource "aws_db_parameter_group" "main" {
  family = "postgres15"
  name   = "${var.project_name}-${var.environment}-postgres-params"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"  # 1초 이상 쿼리 로깅
  }

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  parameter {
    name  = "max_connections"
    value = "200"
  }

  tags = var.tags
}

# 랜덤 패스워드 생성
resource "random_password" "master" {
  length  = 16
  special = true
}

# AWS Secrets Manager에 DB 자격증명 저장
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "${var.project_name}-${var.environment}-db-credentials"
  description             = "Database credentials for MSA Learning Platform"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.master.result
    engine   = "postgres"
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    dbname   = var.db_name
  })
}

# RDS 인스턴스 생성
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-postgres"

  # 엔진 설정
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  # 스토리지 설정
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  # 데이터베이스 설정
  db_name  = var.db_name
  username = var.db_username
  password = random_password.master.result

  # 네트워크 설정
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_security_group_id]
  port                   = 5432

  # 고가용성 설정
  multi_az               = true
  availability_zone      = null  # Multi-AZ에서는 null로 설정

  # 백업 설정
  backup_retention_period = 7
  backup_window          = "03:00-04:00"  # UTC 기준 (JST 12:00-13:00)
  maintenance_window     = "sun:04:00-sun:05:00"  # UTC 기준 (JST 일요일 13:00-14:00)

  # 모니터링 설정
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_enhanced_monitoring.arn

  # Performance Insights 활성화
  performance_insights_enabled = true
  performance_insights_retention_period = 7

  # 파라미터 그룹
  parameter_group_name = aws_db_parameter_group.main.name

  # 로그 설정
  enabled_cloudwatch_logs_exports = ["postgresql"]

  # 삭제 보호 설정 (학습 환경이므로 false)
  deletion_protection = false
  skip_final_snapshot = true

  # 자동 마이너 버전 업그레이드
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-postgres"
  })

  depends_on = [
    aws_db_subnet_group.main,
    aws_db_parameter_group.main
  ]
}

# RDS Enhanced Monitoring을 위한 IAM 역할
resource "aws_iam_role" "rds_enhanced_monitoring" {
  name = "${var.project_name}-${var.environment}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "rds_enhanced_monitoring" {
  role       = aws_iam_role.rds_enhanced_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# CloudWatch 로그 그룹 (PostgreSQL 로그용)
resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/${aws_db_instance.main.identifier}/postgresql"
  retention_in_days = 7

  tags = var.tags
}

# 읽기 전용 복제본 (선택사항 - 학습용으로는 주석 처리)
# resource "aws_db_instance" "read_replica" {
#   identifier = "${var.project_name}-${var.environment}-postgres-replica"
#   
#   replicate_source_db = aws_db_instance.main.identifier
#   instance_class      = var.db_instance_class
#   
#   publicly_accessible = false
#   
#   tags = merge(var.tags, {
#     Name = "${var.project_name}-${var.environment}-postgres-replica"
#   })
# }