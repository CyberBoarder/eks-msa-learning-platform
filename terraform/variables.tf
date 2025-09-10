# Variables for EKS MSA Learning Platform

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-1"  # 도쿄 리전
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "eks-msa-learning"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# VPC 설정
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c", "ap-northeast-1d"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# EKS 설정
variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "node_groups" {
  description = "EKS node groups configuration"
  type = map(object({
    instance_types = list(string)
    capacity_type  = string
    min_size      = number
    max_size      = number
    desired_size  = number
    disk_size     = number
    labels        = map(string)
    taints = list(object({
      key    = string
      value  = string
      effect = string
    }))
  }))
  default = {
    system = {
      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"
      min_size      = 2
      max_size      = 4
      desired_size  = 2
      disk_size     = 50
      labels = {
        role = "system"
      }
      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }
    application = {
      instance_types = ["t3.large"]
      capacity_type  = "ON_DEMAND"
      min_size      = 2
      max_size      = 6
      desired_size  = 2
      disk_size     = 100
      labels = {
        role = "application"
      }
      taints = []
    }
  }
}

# RDS 설정
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "msalearning"
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "dbadmin"
}

# ElastiCache 설정
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

# ECR 설정
variable "ecr_repositories" {
  description = "List of ECR repositories to create"
  type        = list(string)
  default = [
    "frontend-service",
    "main-service", 
    "catalog-service",
    "order-service"
  ]
}