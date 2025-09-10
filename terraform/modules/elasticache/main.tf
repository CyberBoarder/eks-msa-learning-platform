# ElastiCache Redis Module for MSA Learning Platform
# 캐싱 및 세션 스토리지용 Redis 클러스터

# ElastiCache 서브넷 그룹 생성
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = var.tags
}

# ElastiCache 파라미터 그룹 생성 (Redis 최적화)
resource "aws_elasticache_parameter_group" "main" {
  family = "redis7.x"
  name   = "${var.project_name}-${var.environment}-redis-params"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  parameter {
    name  = "maxclients"
    value = "1000"
  }

  tags = var.tags
}

# ElastiCache Redis 클러스터 생성
resource "aws_elasticache_replication_group" "main" {
  replication_group_id       = "${var.project_name}-${var.environment}-redis"
  description                = "Redis cluster for MSA Learning Platform"

  # 노드 설정
  node_type               = var.node_type
  port                    = 6379
  parameter_group_name    = aws_elasticache_parameter_group.main.name

  # 클러스터 설정
  num_cache_clusters      = 2  # Primary + 1 Replica
  
  # 엔진 설정
  engine                  = "redis"
  engine_version          = "7.0"

  # 네트워크 설정
  subnet_group_name       = aws_elasticache_subnet_group.main.name
  security_group_ids      = [var.redis_security_group_id]

  # 백업 설정
  snapshot_retention_limit = 3
  snapshot_window         = "03:00-05:00"  # UTC 기준 (JST 12:00-14:00)
  maintenance_window      = "sun:05:00-sun:07:00"  # UTC 기준 (JST 일요일 14:00-16:00)

  # 고가용성 설정
  automatic_failover_enabled = true
  multi_az_enabled          = true

  # 보안 설정
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                = random_password.redis_auth.result

  # 로그 설정
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  # 알림 설정
  notification_topic_arn = aws_sns_topic.redis_notifications.arn

  # 자동 마이너 버전 업그레이드
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis"
  })

  depends_on = [
    aws_elasticache_subnet_group.main,
    aws_elasticache_parameter_group.main
  ]
}

# Redis 인증 토큰 생성
resource "random_password" "redis_auth" {
  length  = 32
  special = false  # Redis AUTH는 특수문자 제한이 있음
}

# AWS Secrets Manager에 Redis 자격증명 저장
resource "aws_secretsmanager_secret" "redis_auth" {
  name                    = "${var.project_name}-${var.environment}-redis-auth"
  description             = "Redis authentication token for MSA Learning Platform"
  recovery_window_in_days = 7

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id = aws_secretsmanager_secret.redis_auth.id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth.result
    host       = aws_elasticache_replication_group.main.primary_endpoint_address
    port       = aws_elasticache_replication_group.main.port
    engine     = "redis"
  })
}

# CloudWatch 로그 그룹 (Redis Slow Log용)
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/redis/${var.project_name}-${var.environment}/slow-log"
  retention_in_days = 7

  tags = var.tags
}

# SNS 토픽 (Redis 알림용)
resource "aws_sns_topic" "redis_notifications" {
  name = "${var.project_name}-${var.environment}-redis-notifications"

  tags = var.tags
}

# CloudWatch 알람 - CPU 사용률
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redis cpu utilization"
  alarm_actions       = [aws_sns_topic.redis_notifications.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = var.tags
}

# CloudWatch 알람 - 메모리 사용률
resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redis memory utilization"
  alarm_actions       = [aws_sns_topic.redis_notifications.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = var.tags
}

# CloudWatch 알람 - 연결 수
resource "aws_cloudwatch_metric_alarm" "redis_connections" {
  alarm_name          = "${var.project_name}-${var.environment}-redis-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "800"  # maxclients의 80%
  alarm_description   = "This metric monitors redis connection count"
  alarm_actions       = [aws_sns_topic.redis_notifications.arn]

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.main.replication_group_id}-001"
  }

  tags = var.tags
}