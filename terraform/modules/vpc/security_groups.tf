# Security Groups for VPC

# 기본 보안 그룹 - EKS 클러스터용
resource "aws_security_group" "eks_cluster" {
  name_prefix = "${var.project_name}-${var.environment}-eks-cluster-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EKS cluster control plane"

  # HTTPS 트래픽 허용 (EKS API 서버)
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-eks-cluster-sg"
    Type = "EKS-Cluster"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EKS 노드 그룹용 보안 그룹
resource "aws_security_group" "eks_nodes" {
  name_prefix = "${var.project_name}-${var.environment}-eks-nodes-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EKS worker nodes"

  # 노드 간 통신 허용
  ingress {
    description = "Node to node communication"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    self        = true
  }

  # 클러스터에서 노드로의 통신 허용
  ingress {
    description     = "Cluster to node communication"
    from_port       = 1025
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # HTTPS 통신 허용 (kubelet API)
  ingress {
    description     = "Cluster to node HTTPS"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_cluster.id]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-eks-nodes-sg"
    Type = "EKS-Nodes"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# RDS용 보안 그룹
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-${var.environment}-rds-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for RDS database"

  # PostgreSQL 포트 허용 (EKS 노드에서만)
  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # 아웃바운드 트래픽 없음 (데이터베이스는 인바운드만)
  egress {
    description = "No outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-rds-sg"
    Type = "RDS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ElastiCache Redis용 보안 그룹
resource "aws_security_group" "redis" {
  name_prefix = "${var.project_name}-${var.environment}-redis-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for ElastiCache Redis"

  # Redis 포트 허용 (EKS 노드에서만)
  ingress {
    description     = "Redis from EKS nodes"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # 아웃바운드 트래픽 없음
  egress {
    description = "No outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-redis-sg"
    Type = "Redis"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# EFS용 보안 그룹
resource "aws_security_group" "efs" {
  name_prefix = "${var.project_name}-${var.environment}-efs-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for EFS file system"

  # NFS 포트 허용 (EKS 노드에서만)
  ingress {
    description     = "NFS from EKS nodes"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # 아웃바운드 트래픽 없음
  egress {
    description = "No outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = []
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-efs-sg"
    Type = "EFS"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB용 보안 그룹
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-${var.environment}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Application Load Balancer"

  # HTTP 트래픽 허용
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS 트래픽 허용
  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 트래픽 허용
  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-${var.environment}-alb-sg"
    Type = "ALB"
  })

  lifecycle {
    create_before_destroy = true
  }
}