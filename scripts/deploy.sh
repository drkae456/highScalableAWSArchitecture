#!/bin/bash

set -e

# Configuration
AWS_REGION="ap-southeast-4"
ECR_REPOSITORY="high-scalable-aws-app"
GITHUB_REPO="${1:-your-username/your-repo-name}"

echo "🚀 Starting deployment of High Scalable AWS Architecture"
echo "Region: $AWS_REGION"
echo "ECR Repository: $ECR_REPOSITORY"
echo "GitHub Repo: $GITHUB_REPO"

# Check if AWS CLI is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo "❌ AWS CLI is not configured. Please run 'aws configure' first."
    exit 1
fi

# Step 1: Setup ECR with Terraform
echo "📦 Setting up ECR repository with Terraform..."
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    terraform init
fi

terraform plan \
    -var="github_repo=$GITHUB_REPO" \
    -var="aws_region=$AWS_REGION" \
    -var="repository_name=$ECR_REPOSITORY"

terraform apply -auto-approve \
    -var="github_repo=$GITHUB_REPO" \
    -var="aws_region=$AWS_REGION" \
    -var="repository_name=$ECR_REPOSITORY"

# Get ECR repository URL
ECR_REGISTRY=$(terraform output -raw ecr_repository_url)
echo "ECR Registry: $ECR_REGISTRY"

cd ..

# Step 2: Build and push Docker image
echo "🐳 Building and pushing Docker image..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY

# Build image
IMAGE_TAG="$ECR_REGISTRY:latest"
docker build -t $IMAGE_TAG .

# Push image
docker push $IMAGE_TAG

echo "✅ Docker image pushed: $IMAGE_TAG"

# Step 3: Deploy WAF (must be in us-east-1)
echo "🛡️  Deploying WAF in us-east-1..."
aws cloudformation deploy \
    --template-file cform/waf-global.yaml \
    --stack-name high-scalable-waf-global \
    --region us-east-1 \
    --no-fail-on-empty-changeset

# Get WAF ARN
WAF_ARN=$(aws cloudformation describe-stacks \
    --stack-name high-scalable-waf-global \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`WebACLArn`].OutputValue' \
    --output text)

echo "✅ WAF deployed with ARN: $WAF_ARN"

# Step 4: Deploy Network
echo "🌐 Deploying network stack..."
aws cloudformation deploy \
    --template-file cform/network.yaml \
    --stack-name high-scalable-network \
    --region $AWS_REGION \
    --no-fail-on-empty-changeset

echo "✅ Network stack deployed"

# Step 5: Deploy Application
echo "🚀 Deploying application stack..."
aws cloudformation deploy \
    --template-file cform/application.yaml \
    --stack-name high-scalable-application \
    --region $AWS_REGION \
    --parameter-overrides \
        EcrImageUri=$IMAGE_TAG \
        GlobalWebACLArn="$WAF_ARN" \
        LambdaFunctionName=FastApiFunction \
        TableName=OrdersTable \
    --capabilities CAPABILITY_IAM \
    --no-fail-on-empty-changeset

# Get API URL and CloudFront URL
API_URL=$(aws cloudformation describe-stacks \
    --stack-name high-scalable-application \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
    --output text)

CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name high-scalable-application \
    --region $AWS_REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomainName`].OutputValue' \
    --output text)

echo "✅ Application stack deployed!"
echo ""
echo "🎉 Deployment completed successfully!"
echo ""
echo "📍 Endpoints:"
echo "API Gateway: $API_URL"
echo "CloudFront: https://$CLOUDFRONT_URL"
echo ""
echo "🧪 Test commands:"
echo "curl $API_URL"
echo "curl $API_URL/health"
echo "curl https://$CLOUDFRONT_URL"
echo ""
echo "📱 Create an order:"
echo "curl -X POST $API_URL/orders -H 'Content-Type: application/json' -d '{\"customer\": \"John Doe\", \"product\": \"Widget\", \"quantity\": 5}'" 