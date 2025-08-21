# MYCE EKS Integration Variables

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-northeast-2"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "likelion-terraform-current"
}

variable "existing_vpc_id" {
  description = "Existing VPC ID to use"
  type        = string
  default     = "vpc-0b4526653c3bb8f80"
}

variable "existing_alb_arn" {
  description = "Existing ALB ARN to integrate with"
  type        = string
  default     = "arn:aws:elasticloadbalancing:ap-northeast-2:155669502936:loadbalancer/app/myce-backend-alb/f1e8b36e568f98a6"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "myce-demo-eks"
}

variable "node_instance_types" {
  description = "EC2 instance types for EKS nodes"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "node_capacity_type" {
  description = "Capacity type for nodes (ON_DEMAND or SPOT)"
  type        = string
  default     = "SPOT"  # 70% cost savings for demo
}

variable "node_desired_size" {
  description = "Desired number of nodes (always-on for instant scaling)"
  type        = number
  default     = 3
}

variable "node_min_size" {
  description = "Minimum number of nodes (keep 3 always running)"
  type        = number
  default     = 3
}

variable "node_max_size" {
  description = "Maximum number of nodes for auto-scaling"
  type        = number
  default     = 6
}

variable "docker_image" {
  description = "Docker image for MYCE application"
  type        = string
  default     = "juanpark/myce-backend:latest"
}