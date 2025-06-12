# High Scalable AWS Architecture

A production-ready, high-scalable AWS architecture deployed using CloudFormation, Terraform, and GitHub Actions. This project demonstrates a complete CI/CD pipeline that builds and deploys a FastAPI application on AWS Lambda with supporting infrastructure.

## 🏗️ Architecture Overview

This project deploys a comprehensive AWS architecture with the following components:

### Core Infrastructure

- **VPC**: Custom VPC with public/private subnets across 2 AZs
- **NAT Gateways**: High availability internet access for private subnets
- **Security Groups**: Properly configured security groups for Lambda

### Application Layer

- **Lambda Function**: Containerized FastAPI application
- **API Gateway**: HTTP API for REST endpoints
- **CloudFront**: Global CDN for low-latency access
- **S3**: Static asset storage with versioning
- **DynamoDB**: NoSQL database with encryption and point-in-time recovery

### Security & Monitoring

- **WAF**: Web Application Firewall for CloudFront
- **KMS**: Customer-managed encryption keys
- **EventBridge**: Event-driven architecture for decoupling
- **IAM**: Least privilege access policies

### DevOps & CI/CD

- **ECR**: Container registry for Docker images
- **GitHub Actions**: Automated CI/CD pipeline
- **Terraform**: Infrastructure as Code for ECR setup

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **AWS CLI** configured with credentials
3. **Docker** installed locally
4. **Terraform** >= 1.0 installed
5. **GitHub repository** for CI/CD

## 🚀 Quick Start

### Option 1: GitHub Actions (Recommended)

1. **Fork this repository** to your GitHub account

2. **Set up AWS credentials for GitHub Actions:**

   First, you need to set up OIDC for secure authentication. Run this locally:

   ```bash
   # Update the github_repo variable in terraform/main.tf
   cd terraform
   terraform init
   terraform apply -var="github_repo=YOUR_USERNAME/YOUR_REPO_NAME"
   ```

3. **Add the GitHub Secret:**

   Get the role ARN from Terraform output:

   ```bash
   terraform output github_actions_role_arn
   ```

   Add this as `AWS_ROLE_ARN` in your GitHub repository secrets.

4. **Push to main branch** - This will trigger the deployment automatically!

### Option 2: Local Deployment

1. **Configure AWS CLI:**

   ```bash
   aws configure
   ```

2. **Run the deployment script:**
   ```bash
   ./scripts/deploy.sh YOUR_USERNAME/YOUR_REPO_NAME
   ```

## 📦 What Gets Deployed

### GitHub Actions Pipeline

The CI/CD pipeline consists of 5 main jobs:

1. **terraform-setup**: Creates ECR repository and IAM roles
2. **build-and-push**: Builds Docker image and pushes to ECR (only if changed)
3. **deploy-waf**: Deploys WAF in us-east-1 (required for CloudFront)
4. **deploy-network**: Deploys VPC and networking components
5. **deploy-application**: Deploys the complete application stack

### CloudFormation Stacks

- `high-scalable-waf-global` (us-east-1)
- `high-scalable-network` (ap-southeast-4)
- `high-scalable-application` (ap-southeast-4)

## 🧪 Testing the API

Once deployed, you can test the FastAPI application:

```bash
# Get the API URL from CloudFormation outputs
API_URL=$(aws cloudformation describe-stacks \
  --stack-name high-scalable-application \
  --region ap-southeast-4 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' \
  --output text)

# Health check
curl $API_URL/health

# Get API info
curl $API_URL/

# Create an order
curl -X POST $API_URL/orders \
  -H 'Content-Type: application/json' \
  -d '{"customer": "John Doe", "product": "Widget", "quantity": 5}'

# Get the order
ORDER_ID="<order_id_from_previous_response>"
curl $API_URL/orders/$ORDER_ID

# Update order status
curl -X PUT $API_URL/orders/$ORDER_ID/status \
  -H 'Content-Type: application/json' \
  -d '{"status": "shipped"}'

# List all orders
curl $API_URL/orders
```

## 🎯 Key Features

### ✅ Smart Deployment

- Only deploys if Docker image has changed
- Skips redundant builds to save time and costs
- Proper dependency management between stacks

### ✅ Production Ready

- Multi-AZ deployment for high availability
- Encrypted storage (S3, DynamoDB) with customer-managed keyshhh
- WAF protection against common attacks
- CloudFront for global low-latency access

### ✅ Cost Optimized

- Pay-per-request pricing (Lambda, DynamoDB, API Gateway)
- ECR lifecycle policies to manage image storage
- Automatic cleanup scripts to avoid ongoing charges

### ✅ Secure by Default

- VPC isolation with private subnets for Lambda
- IAM roles with least privilege access
- All data encrypted at rest and in transit
- Security groups allowing only necessary traffic

### ✅ Observable

- CloudWatch metrics enabled for all services
- EventBridge for event-driven architecture
- Health check endpoints for monitoring

## 🛠️ Development

### Local Development

You can run the FastAPI application locally:

```bash
cd app
pip install -r requirements.txt
uvicorn main:app --reload
```

Visit http://localhost:8000 for the API and http://localhost:8000/docs for Swagger documentation.

### Project Structure

```
.
├── .github/workflows/
│   └── deploy.yml           # GitHub Actions CI/CD pipeline
├── app/
│   ├── main.py             # FastAPI application
│   └── requirements.txt    # Python dependencies
├── cform/
│   ├── waf-global.yaml     # WAF CloudFormation template
│   ├── network.yaml        # VPC and networking template
│   └── application.yaml    # Application stack template
├── terraform/
│   ├── main.tf            # ECR and IAM resources
│   ├── variables.tf       # Terraform variables
│   └── outputs.tf         # Terraform outputs
├── scripts/
│   ├── deploy.sh          # Local deployment script
│   └── cleanup.sh         # Resource cleanup script
├── Dockerfile             # Container definition
└── README.md
```

## 🧹 Cleanup

To avoid ongoing AWS charges, clean up all resources:

```bash
./scripts/cleanup.sh
```

This will delete:

- All CloudFormation stacks
- ECR repository and images
- Terraform state

## 🔧 Customization

### Environment Variables

The Lambda function uses these environment variables (automatically set by CloudFormation):

- `TABLE_NAME`: DynamoDB table name
- `EVENT_BUS_NAME`: EventBridge custom bus name
- `S3_BUCKET`: S3 bucket name for file uploads

### Scaling Configuration

You can modify the CloudFormation templates to adjust:

- Lambda memory and timeout
- DynamoDB billing mode and capacity
- VPC CIDR blocks and subnet configuration
- CloudFront caching behavior

### Adding New Endpoints

1. Add new routes to `app/main.py`
2. Update any required IAM permissions in `cform/application.yaml`
3. Push changes - GitHub Actions will automatically deploy

## 📚 Architecture Decisions

### Why These Technologies?

- **FastAPI**: Modern, fast Python framework with automatic API documentation
- **Lambda**: Serverless compute with automatic scaling and pay-per-request pricing
- **DynamoDB**: Managed NoSQL database with single-digit millisecond latency
- **CloudFront**: Global CDN for improved performance and DDoS protection
- **EventBridge**: Decoupled, event-driven architecture for scalability
- **Terraform + CloudFormation**: Best of both worlds - Terraform for ECR/IAM, CloudFormation for AWS-native resources

### Regional Deployment

- **us-east-1**: WAF (required for CloudFront)
- **ap-southeast-4**: All other resources (can be changed in variables)

## 🐛 Troubleshooting

### Common Issues

1. **Lambda function not working**: Check CloudWatch logs for the function
2. **API Gateway 502 errors**: Verify Lambda function permissions and VPC configuration
3. **GitHub Actions failing**: Ensure AWS_ROLE_ARN secret is set correctly
4. **Terraform errors**: Check AWS credentials and permissions

### Debugging

```bash
# Check CloudFormation stack status
aws cloudformation describe-stacks --stack-name high-scalable-application

# View Lambda logs
aws logs describe-log-groups --log-group-name-prefix /aws/lambda/FastApiFunction

# Test Lambda function directly
aws lambda invoke --function-name FastApiFunction response.json
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test locally using `./scripts/deploy.sh`
5. Submit a pull request

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review CloudWatch logs for Lambda functions
3. Open an issue with detailed error messages and steps to reproduce
