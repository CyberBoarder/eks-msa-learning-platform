# AWS EKS MSA Learning Platform - Main Terraform Configuration
# Region: Tokyo (ap-northeast-1)

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }
}

# AWS Provider 설정 - 도쿄 리전
provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "EKS-MSA-Learning-Platform"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Kubernetes Provider 설정
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# Helm Provider 설정
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}

# 로컬 변수 정의
locals {
  cluster_name = "${var.project_name}-${var.environment}"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# VPC 모듈 호출
module "vpc" {
  source = "./modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  
  tags = local.common_tags
}

# EKS 모듈 호출
module "eks" {
  source = "./modules/eks"
  
  cluster_name    = local.cluster_name
  cluster_version = var.cluster_version
  
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.private_subnet_ids
  
  node_security_group_id = module.vpc.eks_nodes_security_group_id
  
  node_groups = var.node_groups
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# RDS 모듈 호출
module "rds" {
  source = "./modules/rds"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  rds_security_group_id = module.vpc.rds_security_group_id
  
  db_instance_class = var.db_instance_class
  db_name          = var.db_name
  db_username      = var.db_username
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# ElastiCache 모듈 호출
module "elasticache" {
  source = "./modules/elasticache"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  redis_security_group_id = module.vpc.redis_security_group_id
  
  node_type = var.redis_node_type
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# S3 모듈 호출
module "s3" {
  source = "./modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = local.common_tags
}

# EFS 모듈 호출
module "efs" {
  source = "./modules/efs"
  
  project_name = var.project_name
  environment  = var.environment
  
  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  
  efs_security_group_id = module.vpc.efs_security_group_id
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# ECR 모듈 호출
module "ecr" {
  source = "./modules/ecr"
  
  project_name = var.project_name
  environment  = var.environment
  
  repositories = var.ecr_repositories
  
  tags = local.common_tags
}