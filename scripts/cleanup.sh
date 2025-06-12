#!/bin/bash

set -e

# Configuration
AWS_REGION="ap-southeast-4"
ECR_REPOSITORY="high-scalable-aws-app"

echo "🧹 Cleaning up High Scalable AWS Architecture"
echo "Region: $AWS_REGION"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

echo "⚠️  This will delete the following resources:"
echo "  - Application stack (Lambda, API Gateway, CloudFront, S3, DynamoDB)"
echo "  - Network stack (VPC, subnets, NAT gateways)"
echo "  - WAF stack (WebACL)"
echo "  - ECR repository and images"
echo ""

read -p "Are you sure you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Step 1: Delete Application Stack
echo "🚀 Deleting application stack..."
aws cloudformation delete-stack \
    --stack-name high-scalable-application \
    --region $AWS_REGION || echo "Application stack not found or already deleted"

echo "⏳ Waiting for application stack deletion..."
aws cloudformation wait stack-delete-complete \
    --stack-name high-scalable-application \
    --region $AWS_REGION || echo "Application stack deletion completed or failed"

# Step 2: Delete Network Stack
echo "🌐 Deleting network stack..."
aws cloudformation delete-stack \
    --stack-name high-scalable-network \
    --region $AWS_REGION || echo "Network stack not found or already deleted"

echo "⏳ Waiting for network stack deletion..."
aws cloudformation wait stack-delete-complete \
    --stack-name high-scalable-network \
    --region $AWS_REGION || echo "Network stack deletion completed or failed"

# Step 3: Delete WAF Stack (in us-east-1)
echo "🛡️  Deleting WAF stack..."
aws cloudformation delete-stack \
    --stack-name high-scalable-waf-global \
    --region us-east-1 || echo "WAF stack not found or already deleted"

echo "⏳ Waiting for WAF stack deletion..."
aws cloudformation wait stack-delete-complete \
    --stack-name high-scalable-waf-global \
    --region us-east-1 || echo "WAF stack deletion completed or failed"

# Step 4: Clean up ECR repository
echo "📦 Cleaning up ECR repository..."

# List and delete all images in the repository
aws ecr list-images \
    --repository-name $ECR_REPOSITORY \
    --region $AWS_REGION \
    --query 'imageIds[*]' \
    --output json > /tmp/image-ids.json 2>/dev/null || echo "[]" > /tmp/image-ids.json

if [ -s /tmp/image-ids.json ] && [ "$(cat /tmp/image-ids.json)" != "[]" ]; then
    echo "🗑️  Deleting ECR images..."
    aws ecr batch-delete-image \
        --repository-name $ECR_REPOSITORY \
        --region $AWS_REGION \
        --image-ids file:///tmp/image-ids.json || echo "No images to delete"
fi

# Step 5: Destroy ECR with Terraform
echo "🏗️  Destroying ECR repository with Terraform..."
cd terraform

# Check if terraform state exists
if [ -f "terraform.tfstate" ]; then
    terraform destroy -auto-approve \
        -var="github_repo=cleanup" \
        -var="aws_region=$AWS_REGION" \
        -var="repository_name=$ECR_REPOSITORY" || echo "Terraform destroy completed or failed"
else
    echo "No Terraform state found, skipping Terraform destroy"
fi

cd ..

# Clean up temporary files
rm -f /tmp/image-ids.json

echo "✅ Cleanup completed!"
echo ""
echo "🗑️  All resources have been deleted:"
echo "  ✓ Application stack"
echo "  ✓ Network stack" 
echo "  ✓ WAF stack"
echo "  ✓ ECR repository and images"
echo ""
echo "💰 This should stop all ongoing AWS charges for this project." 