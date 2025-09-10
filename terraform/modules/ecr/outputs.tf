# Outputs for ECR Module

output "repository_arns" {
  description = "ARNs of the ECR repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.arn }
}

output "repository_urls" {
  description = "URLs of the ECR repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.repository_url }
}

output "repository_registry_ids" {
  description = "Registry IDs of the ECR repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.registry_id }
}

output "repository_names" {
  description = "Names of the ECR repositories"
  value       = { for k, v in aws_ecr_repository.repositories : k => v.name }
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for ECR scan results"
  value       = aws_cloudwatch_log_group.ecr_scan_results.name
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule for ECR scan events"
  value       = aws_cloudwatch_event_rule.ecr_scan_complete.name
}

# 취약점 알람 출력
output "high_severity_alarm_names" {
  description = "Names of the high severity vulnerability alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ecr_high_severity_vulnerabilities : k => v.alarm_name }
}

output "critical_severity_alarm_names" {
  description = "Names of the critical severity vulnerability alarms"
  value       = { for k, v in aws_cloudwatch_metric_alarm.ecr_critical_severity_vulnerabilities : k => v.alarm_name }
}