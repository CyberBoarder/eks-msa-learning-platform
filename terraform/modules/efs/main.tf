# EFS Module for MSA Learning Platform
# 공유 파일 시스템 및 영구 스토리지용

# EFS 파일 시스템 생성
resource "aws_efs_file_system" "main" {
  creation_token = "${var.project_name}-${var.environment}-efs"
  
  # 성능 모드 설정
  performance_mode = "generalPurpose"
  throughput_mode  = "provisioned"
  provisioned_throughput_in_mibps = 100

  # 암호화 설정
  encrypted = true

  # 라이프사이클 정책 설정
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }

  lifecycle_policy {
    transition_to_primary_storage_class = "AFTER_1_ACCESS"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-efs"
  })
}

# EFS 마운트 타겟 생성 (각 프라이빗 서브넷에)
resource "aws_efs_mount_target" "main" {
  count = length(var.private_subnet_ids)

  file_system_id  = aws_efs_file_system.main.id
  subnet_id       = var.private_subnet_ids[count.index]
  security_groups = [var.efs_security_group_id]
}

# EFS 액세스 포인트 생성 (애플리케이션별)
resource "aws_efs_access_point" "app_data" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/app-data"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-app-data-ap"
    Purpose = "Application data storage"
  })
}

resource "aws_efs_access_point" "shared_config" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/shared-config"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-shared-config-ap"
    Purpose = "Shared configuration files"
  })
}

resource "aws_efs_access_point" "logs" {
  file_system_id = aws_efs_file_system.main.id

  posix_user {
    gid = 1000
    uid = 1000
  }

  root_directory {
    path = "/logs"
    creation_info {
      owner_gid   = 1000
      owner_uid   = 1000
      permissions = "755"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-logs-ap"
    Purpose = "Application logs storage"
  })
}

# EFS 백업 정책
resource "aws_efs_backup_policy" "main" {
  file_system_id = aws_efs_file_system.main.id

  backup_policy {
    status = "ENABLED"
  }
}

# CloudWatch 로그 그룹 (EFS 성능 메트릭용)
resource "aws_cloudwatch_log_group" "efs_performance" {
  name              = "/aws/efs/${var.project_name}-${var.environment}/performance"
  retention_in_days = 7

  tags = var.tags
}

# CloudWatch 알람 - 총 IO 시간
resource "aws_cloudwatch_metric_alarm" "efs_total_io_time" {
  alarm_name          = "${var.project_name}-${var.environment}-efs-total-io-time-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TotalIOTime"
  namespace           = "AWS/EFS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "80"
  alarm_description   = "This metric monitors EFS total IO time"
  
  dimensions = {
    FileSystemId = aws_efs_file_system.main.id
  }

  tags = var.tags
}

# CloudWatch 알람 - 처리량 사용률
resource "aws_cloudwatch_metric_alarm" "efs_throughput_utilization" {
  alarm_name          = "${var.project_name}-${var.environment}-efs-throughput-utilization-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "PercentIOLimit"
  namespace           = "AWS/EFS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors EFS throughput utilization"
  
  dimensions = {
    FileSystemId = aws_efs_file_system.main.id
  }

  tags = var.tags
}

# EFS 파일 시스템 정책 (선택사항)
resource "aws_efs_file_system_policy" "main" {
  file_system_id = aws_efs_file_system.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyInsecureConnections"
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action   = "*"
        Resource = aws_efs_file_system.main.arn
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}