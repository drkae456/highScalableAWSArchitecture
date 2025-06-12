variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-4"
}

variable "repository_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "high-scalable-aws-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "high-scalable-aws"
}

variable "github_repo" {
  description = "GitHub repository in the format owner/repo-name"
  type        = string
  # This should be set via environment variable or terraform.tfvars
} 