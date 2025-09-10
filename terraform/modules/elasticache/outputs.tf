# Outputs for ElastiCache Module

output "redis_replication_group_id" {
  description = "ID of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.replication_group_id
}

output "redis_replication_group_arn" {
  description = "ARN of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.main.arn
}

output "redis_primary_endpoint_address" {
  description = "Address of the endpoint for the primary node in the replication group"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "redis_reader_endpoint_address" {
  description = "Address of the endpoint for the reader node in the replication group"
  value       = aws_elasticache_replication_group.main.reader_endpoint_address
  sensitive   = true
}

output "redis_endpoint" {
  description = "Redis primary endpoint (for backward compatibility)"
  value       = aws_elasticache_replication_group.main.primary_endpoint_address
  sensitive   = true
}

output "redis_port" {
  description = "Port number on which the cache nodes accept connections"
  value       = aws_elasticache_replication_group.main.port
}

output "redis_configuration_endpoint_address" {
  description = "Address of the replication group configuration endpoint when cluster mode is enabled"
  value       = aws_elasticache_replication_group.main.configuration_endpoint_address
  sensitive   = true
}

output "redis_member_clusters" {
  description = "Identifiers of all the nodes that are part of this replication group"
  value       = aws_elasticache_replication_group.main.member_clusters
}

output "redis_subnet_group_name" {
  description = "Name of the cache subnet group"
  value       = aws_elasticache_subnet_group.main.name
}

output "redis_parameter_group_name" {
  description = "Name of the parameter group"
  value       = aws_elasticache_parameter_group.main.name
}

output "redis_auth_secret_arn" {
  description = "ARN of the secret containing Redis authentication token"
  value       = aws_secretsmanager_secret.redis_auth.arn
}

output "redis_auth_secret_name" {
  description = "Name of the secret containing Redis authentication token"
  value       = aws_secretsmanager_secret.redis_auth.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Redis slow logs"
  value       = aws_cloudwatch_log_group.redis_slow.name
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for Redis notifications"
  value       = aws_sns_topic.redis_notifications.arn
}

# CloudWatch 알람 출력
output "cpu_alarm_name" {
  description = "Name of the CPU utilization alarm"
  value       = aws_cloudwatch_metric_alarm.redis_cpu.alarm_name
}

output "memory_alarm_name" {
  description = "Name of the memory utilization alarm"
  value       = aws_cloudwatch_metric_alarm.redis_memory.alarm_name
}

output "connections_alarm_name" {
  description = "Name of the connections count alarm"
  value       = aws_cloudwatch_metric_alarm.redis_connections.alarm_name
}