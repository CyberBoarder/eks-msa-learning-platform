# Variables for EFS Module

variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where EFS will be created"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for EFS mount targets"
  type        = list(string)
}

variable "efs_security_group_id" {
  description = "Security group ID for EFS"
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resource"
  type        = map(string)
  default     = {}
}