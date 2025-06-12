terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Look up the existing ECR repository
data "aws_ecr_repository" "app_repo" {
  name = var.repository_name
}

# ECR Lifecycle Policy
resource "aws_ecr_lifecycle_policy" "app_repo_policy" {
  repository = data.aws_ecr_repository.app_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["v"]
          countType     = "imageCountMoreThan"
          countNumber   = 30
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images older than 1 day"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 1
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Reference existing GitHub Actions IAM role (created manually)
# Note: This assumes you already created the IAM role and OIDC provider manually
# The role ARN is stored in GitHub secrets as AWS_ROLE_ARN 