# ECR Module for MSA Learning Platform
# 컨테이너 이미지 저장소

# ECR 리포지토리 생성
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.repositories)

  name                 = "${var.project_name}-${var.environment}-${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-${each.value}"
    Service = each.value
  })
}

# ECR 라이프사이클 정책
resource "aws_ecr_lifecycle_policy" "repositories" {
  for_each = aws_ecr_repository.repositories

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 production images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["prod", "production", "release"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Keep last 5 staging images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["staging", "stage", "dev"]
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 3
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 4
        description  = "Keep only last 3 images for any other tags"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 20
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR 리포지토리 정책 (크로스 계정 액세스 등)
resource "aws_ecr_repository_policy" "repositories" {
  for_each = aws_ecr_repository.repositories

  repository = each.value.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPushPull"
        Effect = "Allow"
        Principal = {
          AWS = [
            "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          ]
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:DescribeRepositories",
          "ecr:GetRepositoryPolicy",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:BatchDeleteImage",
          "ecr:GetLifecyclePolicy",
          "ecr:GetLifecyclePolicyPreview",
          "ecr:ListTagsForResource",
          "ecr:DescribeImageScanFindings"
        ]
      }
    ]
  })
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# CloudWatch 로그 그룹 (ECR 이미지 스캔 결과용)
resource "aws_cloudwatch_log_group" "ecr_scan_results" {
  name              = "/aws/ecr/${var.project_name}-${var.environment}/scan-results"
  retention_in_days = 30

  tags = var.tags
}

# EventBridge 규칙 (이미지 스캔 완료 이벤트)
resource "aws_cloudwatch_event_rule" "ecr_scan_complete" {
  name        = "${var.project_name}-${var.environment}-ecr-scan-complete"
  description = "Capture ECR image scan completion events"

  event_pattern = jsonencode({
    source      = ["aws.ecr"]
    detail-type = ["ECR Image Scan"]
    detail = {
      scan-status = ["COMPLETE"]
      repository-name = [for repo in var.repositories : "${var.project_name}-${var.environment}-${repo}"]
    }
  })

  tags = var.tags
}

# EventBridge 타겟 (CloudWatch Logs)
resource "aws_cloudwatch_event_target" "ecr_scan_logs" {
  rule      = aws_cloudwatch_event_rule.ecr_scan_complete.name
  target_id = "ECRScanLogsTarget"
  arn       = aws_cloudwatch_log_group.ecr_scan_results.arn
}

# CloudWatch 알람 - 높은 심각도 취약점 발견
resource "aws_cloudwatch_metric_alarm" "ecr_high_severity_vulnerabilities" {
  for_each = aws_ecr_repository.repositories

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-high-severity-vulnerabilities"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "HighSeverityVulnerabilityCount"
  namespace           = "AWS/ECR"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors high severity vulnerabilities in ECR images"
  treat_missing_data  = "notBreaching"

  dimensions = {
    RepositoryName = each.value.name
  }

  tags = var.tags
}

# CloudWatch 알람 - 치명적 심각도 취약점 발견
resource "aws_cloudwatch_metric_alarm" "ecr_critical_severity_vulnerabilities" {
  for_each = aws_ecr_repository.repositories

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-critical-severity-vulnerabilities"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CriticalSeverityVulnerabilityCount"
  namespace           = "AWS/ECR"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "0"
  alarm_description   = "This metric monitors critical severity vulnerabilities in ECR images"
  treat_missing_data  = "notBreaching"

  dimensions = {
    RepositoryName = each.value.name
  }

  tags = var.tags
}