# Outputs for EKS MSA Learning Platform

# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.vpc.public_subnet_ids
}

# EKS Outputs
output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = module.eks.cluster_iam_role_arn
}

output "node_groups" {
  description = "EKS node groups"
  value       = module.eks.node_groups
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Provider for IRSA"
  value       = module.eks.oidc_provider_arn
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = module.rds.db_instance_endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = module.rds.db_instance_port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = module.rds.db_instance_name
}

# ElastiCache Outputs
output "redis_endpoint" {
  description = "ElastiCache Redis endpoint"
  value       = module.elasticache.redis_endpoint
  sensitive   = true
}

output "redis_port" {
  description = "ElastiCache Redis port"
  value       = module.elasticache.redis_port
}

# S3 Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = module.s3.bucket_arn
}

# EFS Outputs
output "efs_id" {
  description = "ID of the EFS file system"
  value       = module.efs.efs_id
}

output "efs_dns_name" {
  description = "DNS name of the EFS file system"
  value       = module.efs.efs_dns_name
}

# ECR Outputs
output "ecr_repositories" {
  description = "ECR repository URLs"
  value       = module.ecr.repository_urls
}

# kubectl 설정을 위한 명령어
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks --region ${var.aws_region} update-kubeconfig --name ${module.eks.cluster_name}"
}