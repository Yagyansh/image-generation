#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT_NAME="${PROJECT_NAME:-chronicle-image-api}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}"
ECR_REPO="${ECR_REPO:-${PROJECT_NAME}}"
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

INFRA_DIR="infra/prod"
TFVARS_FILE="${INFRA_DIR}/terraform.tfvars"

echo "======================================"
echo "Image API – Setup Script"
echo "======================================"
echo "AWS Account: ${AWS_ACCOUNT_ID}"
echo "Region:      ${AWS_REGION}"
echo "Project:     ${PROJECT_NAME}"
echo "Image Tag:   ${IMAGE_TAG}"
echo "Repo:        ${ECR_URI}"
echo "--------------------------------------"

echo "Building Docker image"
docker build -t ${PROJECT_NAME}:${IMAGE_TAG} .

echo "Logging into ECR"
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "Ensuring ECR repository exists"
aws ecr describe-repositories --repository-names "${ECR_REPO}" --region "${AWS_REGION}" >/dev/null 2>&1 || \
  aws ecr create-repository --repository-name "${ECR_REPO}" --region "${AWS_REGION}" >/dev/null

echo "Tagging & pushing image"
docker tag "${PROJECT_NAME}:${IMAGE_TAG}" "${ECR_URI}:${IMAGE_TAG}"
docker push "${ECR_URI}:${IMAGE_TAG}"


echo "Deploying infrastructure via Terraform"
pushd "${INFRA_DIR}" >/dev/null

terraform init -input=false
terraform apply -auto-approve \
  -var "aws_region=${AWS_REGION}" \
  -var "ecr_repo_name=${ECR_REPO}" \
  -var "project=${PROJECT_NAME}" \
  -var "api_keys=${API_KEYS:-local-dev-key}" \
  -var "acm_certificate_arn=${ACM_CERT_ARN:-}" \
  -var "s3_bucket_name=${S3_BUCKET_NAME:-${PROJECT_NAME}-images-${AWS_ACCOUNT_ID}}" \
  -var "db_username=${DB_USERNAME:-chronicle}" \
  -var "db_allocated_storage=${DB_ALLOCATED_STORAGE:-20}"

popd >/dev/null

echo "Fetching deployment outputs"
API_URL=$(terraform -chdir=${INFRA_DIR} output -raw alb_dns 2>/dev/null || echo "")
CDN_URL=$(terraform -chdir=${INFRA_DIR} output -raw cloudfront_domain 2>/dev/null || echo "")
S3_BUCKET=$(terraform -chdir=${INFRA_DIR} output -raw s3_bucket 2>/dev/null || echo "")
ECR_REPO_URL=$(terraform -chdir=${INFRA_DIR} output -raw ecr_repo 2>/dev/null || echo "")

echo ""
echo "======================================"
echo "Image API Deployment Complete!"
echo "======================================"
if [ -n "${API_URL}" ]; then
  echo "API URL:          https://${API_URL}"
else
  echo "API URL:          (not found in TF outputs)"
fi
if [ -n "${CDN_URL}" ]; then
  echo "CloudFront CDN:   https://${CDN_URL}"
else
  echo "CloudFront CDN:   (not found in TF outputs)"
fi
echo "S3 Bucket:        ${S3_BUCKET}"
echo "ECR Repository:   ${ECR_REPO_URL}"
echo "--------------------------------------"
echo "💡 Tip: To test your API, run:"
echo "curl -X POST https://${API_URL}/v1/generate -H 'Authorization: Bearer local-dev-key' -d '{\"prompt\": \"A futuristic city\"}'"
echo "======================================"
