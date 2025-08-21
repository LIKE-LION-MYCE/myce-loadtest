#!/bin/bash
set -e

echo "🔐 Fetching environment variables from AWS Systems Manager Parameter Store..."

# For EKS pods using IRSA, AWS CLI should automatically use the web identity token
# But we need to ensure the region is set
export AWS_REGION="${AWS_REGION:-ap-northeast-2}"
export AWS_DEFAULT_REGION="${AWS_REGION}"

# Debug: Check AWS identity
echo "AWS Identity Check:"
aws sts get-caller-identity || echo "Warning: Could not get caller identity"

# Fetch all required environment variables from SSM
export DB_URL=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/db-url" --with-decryption --query "Parameter.Value" --output text)
export DB_USERNAME=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/db-username" --query "Parameter.Value" --output text)
export DB_PASSWORD=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/db-password" --with-decryption --query "Parameter.Value" --output text)
export DB_DRIVER_CLASS_NAME="com.mysql.cj.jdbc.Driver"

export MONGODB_URI=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/mongodb-uri" --with-decryption --query "Parameter.Value" --output text)
export REDIS_URL=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/redis-url" --with-decryption --query "Parameter.Value" --output text)
export JWT_SECRET=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/jwt-secret" --with-decryption --query "Parameter.Value" --output text)

# AWS configuration
export S3_MEDIA_BUCKET_NAME=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/s3-bucket-name" --query "Parameter.Value" --output text)
export CLOUDFRONT_DOMAIN=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/cloudfront-domain" --query "Parameter.Value" --output text)

# PortOne payment configuration
export PORTONE_BASE_URL=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/portone-base-url" --query "Parameter.Value" --output text)
export PORTONE_API_KEY=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/portone-api-key" --with-decryption --query "Parameter.Value" --output text)
export PORTONE_API_SECRET=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/portone-api-secret" --with-decryption --query "Parameter.Value" --output text)
export PORTONE_CUSTOMER_CODE=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/portone-customer-code" --query "Parameter.Value" --output text)

# Amazon SES email configuration  
export MAIL_HOST=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/ses-smtp-host" --query "Parameter.Value" --output text)
export MAIL_USERNAME=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/ses-smtp-username" --with-decryption --query "Parameter.Value" --output text)
export MAIL_PASSWORD=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/ses-smtp-password" --with-decryption --query "Parameter.Value" --output text)

# OAuth2 configuration
export GOOGLE_CLIENT_ID=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/GOOGLE_CLIENT_ID" --query "Parameter.Value" --output text)
export GOOGLE_CLIENT_SECRET=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/GOOGLE_CLIENT_SECRET" --with-decryption --query "Parameter.Value" --output text)
export KAKAO_CLIENT_ID=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/KAKAO_CLIENT_ID" --query "Parameter.Value" --output text)
export KAKAO_CLIENT_SECRET=$(aws ssm get-parameter --region ${AWS_REGION} --name "/myce/KAKAO_CLIENT_SECRET" --with-decryption --query "Parameter.Value" --output text)

# Set profile for production
export PROFILE="${PROFILE:-product}"

# Debug: Print critical env vars (without sensitive data)
echo "✅ Successfully loaded environment variables from SSM Parameter Store"
echo "DB_URL is set: $([ -n "$DB_URL" ] && echo "YES" || echo "NO")"
echo "Profile: $PROFILE"
echo "Region: $AWS_REGION"

echo "🚀 Starting Spring Boot application..."

# Start the Spring Boot application
exec java -Duser.timezone=Asia/Seoul -jar /app/app.jar