# S3 Module for MSA Learning Platform
# 파일 업로드, 로그 아카이브, kube-bench 결과 저장용

# S3 버킷 생성
resource "aws_s3_bucket" "main" {
  bucket = "${var.project_name}-${var.environment}-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-main-bucket"
    Purpose = "File uploads, logs, and security scan results"
  })
}

# 버킷 이름 충돌 방지를 위한 랜덤 문자열
resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# 버킷 버전 관리 설정
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 버킷 암호화 설정
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 퍼블릭 액세스 차단 설정
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 버킷 정책 설정
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureConnections"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.main]
}

# 라이프사이클 정책 설정
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  rule {
    id     = "uploads_lifecycle"
    status = "Enabled"

    filter {
      prefix = "uploads/"
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365
    }
  }

  rule {
    id     = "security_scans_lifecycle"
    status = "Enabled"

    filter {
      prefix = "security-scans/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }

  depends_on = [aws_s3_bucket_versioning.main]
}

# CORS 설정 (웹 애플리케이션에서 직접 업로드용)
resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "PUT", "POST", "DELETE", "HEAD"]
    allowed_origins = ["*"]  # 실제 운영시에는 특정 도메인으로 제한
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 알림 설정 (선택사항)
resource "aws_s3_bucket_notification" "main" {
  bucket = aws_s3_bucket.main.id

  cloudwatch_configuration {
    cloudwatch_configuration_id = "security-scan-notification"
    filter_prefix              = "security-scans/"
    filter_suffix              = ".json"
  }
}

# CloudWatch 메트릭 설정
resource "aws_s3_bucket_metric" "main" {
  bucket = aws_s3_bucket.main.id
  name   = "EntireBucket"
}

# 로그 버킷 (액세스 로그용)
resource "aws_s3_bucket" "logs" {
  bucket = "${var.project_name}-${var.environment}-access-logs-${random_string.bucket_suffix.result}"

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-access-logs"
    Purpose = "S3 access logs"
  })
}

# 로그 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# 로그 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 메인 버킷 액세스 로깅 설정
resource "aws_s3_bucket_logging" "main" {
  bucket = aws_s3_bucket.main.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

# 로그 버킷 라이프사이클 정책
resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "access_logs_lifecycle"
    status = "Enabled"

    expiration {
      days = 90
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }
}