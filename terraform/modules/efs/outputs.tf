# Outputs for EFS Module

output "efs_id" {
  description = "ID of the EFS file system"
  value       = aws_efs_file_system.main.id
}

output "efs_arn" {
  description = "ARN of the EFS file system"
  value       = aws_efs_file_system.main.arn
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = aws_efs_file_system.main.dns_name
}

output "efs_size_in_bytes" {
  description = "Size of the EFS file system in bytes"
  value       = aws_efs_file_system.main.size_in_bytes
}

output "mount_target_ids" {
  description = "IDs of the EFS mount targets"
  value       = aws_efs_mount_target.main[*].id
}

output "mount_target_dns_names" {
  description = "DNS names of the EFS mount targets"
  value       = aws_efs_mount_target.main[*].dns_name
}

output "mount_target_network_interface_ids" {
  description = "Network interface IDs of the EFS mount targets"
  value       = aws_efs_mount_target.main[*].network_interface_id
}

# Access Point Outputs
output "app_data_access_point_id" {
  description = "ID of the app data access point"
  value       = aws_efs_access_point.app_data.id
}

output "app_data_access_point_arn" {
  description = "ARN of the app data access point"
  value       = aws_efs_access_point.app_data.arn
}

output "shared_config_access_point_id" {
  description = "ID of the shared config access point"
  value       = aws_efs_access_point.shared_config.id
}

output "shared_config_access_point_arn" {
  description = "ARN of the shared config access point"
  value       = aws_efs_access_point.shared_config.arn
}

output "logs_access_point_id" {
  description = "ID of the logs access point"
  value       = aws_efs_access_point.logs.id
}

output "logs_access_point_arn" {
  description = "ARN of the logs access point"
  value       = aws_efs_access_point.logs.arn
}

# CloudWatch Alarm Outputs
output "total_io_time_alarm_name" {
  description = "Name of the total IO time alarm"
  value       = aws_cloudwatch_metric_alarm.efs_total_io_time.alarm_name
}

output "throughput_utilization_alarm_name" {
  description = "Name of the throughput utilization alarm"
  value       = aws_cloudwatch_metric_alarm.efs_throughput_utilization.alarm_name
}