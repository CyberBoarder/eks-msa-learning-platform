# Outputs for RDS Module

output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.main.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "db_instance_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

output "db_instance_username" {
  description = "RDS instance username"
  value       = aws_db_instance.main.username
  sensitive   = true
}

output "db_subnet_group_id" {
  description = "DB subnet group ID"
  value       = aws_db_subnet_group.main.id
}

output "db_subnet_group_arn" {
  description = "DB subnet group ARN"
  value       = aws_db_subnet_group.main.arn
}

output "db_parameter_group_id" {
  description = "DB parameter group ID"
  value       = aws_db_parameter_group.main.id
}

output "db_parameter_group_arn" {
  description = "DB parameter group ARN"
  value       = aws_db_parameter_group.main.arn
}

output "db_secret_arn" {
  description = "ARN of the secret containing database credentials"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "db_secret_name" {
  description = "Name of the secret containing database credentials"
  value       = aws_secretsmanager_secret.db_password.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for PostgreSQL logs"
  value       = aws_cloudwatch_log_group.postgresql.name
}

output "monitoring_role_arn" {
  description = "ARN of the IAM role for RDS enhanced monitoring"
  value       = aws_iam_role.rds_enhanced_monitoring.arn
}