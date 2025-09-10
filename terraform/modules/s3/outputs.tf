# Outputs for S3 Module

output "bucket_id" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.main.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name"
  value       = aws_s3_bucket.main.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "The bucket region-specific domain name"
  value       = aws_s3_bucket.main.bucket_regional_domain_name
}

output "logs_bucket_id" {
  description = "Name of the S3 logs bucket"
  value       = aws_s3_bucket.logs.id
}

output "logs_bucket_name" {
  description = "Name of the S3 logs bucket"
  value       = aws_s3_bucket.logs.bucket
}

output "logs_bucket_arn" {
  description = "ARN of the S3 logs bucket"
  value       = aws_s3_bucket.logs.arn
}