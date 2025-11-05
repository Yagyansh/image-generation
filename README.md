# Image API

A scalable **Image Generation API** built with **Node.js + TypeScript + AWS (ECS, S3, SQS, RDS, CloudFront).**

---

## Overview

**Architecture summary:**

```
Client → Fastify API (ECS Fargate)
   ↓ enqueue
SQS Queue → Worker (ECS Fargate)
   ↓ generate image
S3 (private) → CloudFront (CDN URL)
   ↑ result in Postgres (RDS)
```

### What it does
- Accepts `text` (and optional reference images)
- Enqueues a job in **SQS**
- **Worker** generates an image (mock or OpenAI)
- Uploads image to **S3**, served via **CloudFront**
- Returns a **permanent CDN URL**

---

## Stack

| Layer | Tech |
|-------|------|
| Runtime | Node.js + TypeScript |
| Framework | Fastify |
| Infra | AWS ECS Fargate, S3, SQS, RDS (Postgres), CloudFront |
| IaC | Terraform |
| CI/CD | GitHub Actions |
| Local Dev | Docker Compose + LocalStack + Postgres |
| ORM | Prisma |

---

## Prerequisites

- Node ≥ 18
- Docker + Docker Compose
- AWS CLI or `awslocal`
- Terraform ≥ 1.3
- `jq` (optional for pretty JSON)

---

## Project structure

```
image-generation/
├── src/
│   ├── index.ts
│   ├── worker.ts
│   ├── jobQueue.ts
│   ├── imageGen.ts
│   ├── s3.ts
│   └── db.ts
├── prisma/schema.prisma
├── infra/
│   ├── modules/
│   └── prod/
├── docker-compose.yml
├── Dockerfile
├── setup.sh
└── .env.example
```

---

## Environment variables

| Variable | Description |
|-----------|-------------|
| `PORT` | API port (default 3000) |
| `AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `SQS_QUEUE_URL` | SQS queue URL |
| `IMAGE_S3_BUCKET` | S3 bucket name |
| `CLOUDFRONT_URL` | CloudFront base URL |
| `DATABASE_URL` | Postgres connection string |
| `IMAGE_PROVIDER` | `mock` or `openai` |
| `IMAGE_API_KEY` | API key for OpenAI (if used) |
| `API_KEYS` | Comma-separated list of valid API keys |

---

## Local Development (no AWS required)

Local development uses **Docker Compose + LocalStack + Postgres**.

### 1️⃣ Set up environment
```bash
cp .env.example .env
```

### 2️⃣ Start services
```bash
docker-compose up -d
```

### 3️⃣ Create LocalStack resources

> ⚠️ **Important:** LocalStack requires dummy credentials and region.

Run either:

```bash
# Option A – safest method (requires awscli-local)
pip install awscli-local
awslocal sqs create-queue --queue-name image-jobs
awslocal s3 mb s3://image-gen-bucket
```

or, if using normal AWS CLI:

```bash
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

aws --region us-east-1 --endpoint-url=http://localhost:4566 sqs create-queue --queue-name image-jobs
aws --region us-east-1 --endpoint-url=http://localhost:4566 s3 mb s3://image-gen-bucket
```

Expected output:
```
{
  "QueueUrl": "http://localhost:4566/000000000000/image-jobs"
}
make_bucket: image-gen-bucket
```

### 4️⃣ Install dependencies
```bash
npm install
npx prisma generate
npx prisma migrate dev --name init
```

### 5️⃣ Run services
```bash
npm run dev
npm run dev:worker
```

### 6️⃣ Test the flow
```bash
curl -X POST http://localhost:3000/v1/generate \
  -H "Authorization: Bearer local-dev-key" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "A red cat playing guitar"}'
```

Response:
```json
{
  "jobId": "uuid",
  "statusUrl": "/v1/result/uuid"
}
```

Poll for result:
```bash
curl http://localhost:3000/v1/result/<jobId>
```

---

## ☁️ Deploy to AWS (production)

### 1️⃣ Prerequisites
- AWS CLI configured (`aws configure`)
- Terraform access
- IAM role/user with full privileges
- ACM certificate for ALB HTTPS

### 2️⃣ Export deploy vars
```bash
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export PROJECT_NAME=image-api
export API_KEYS="your-prod-api-key"
export ACM_CERT_ARN="arn:aws:acm:us-east-1:123456789012:certificate/xxxx"
```

### 3️⃣ Run setup script
```bash
chmod +x setup.sh
./setup.sh
```

Output example:
```
Image API Deployment Complete!
API URL:        https://alpha-api-alb-123456.elb.amazonaws.com
CloudFront CDN: https://d3example.cloudfront.net
S3 Bucket:      beta-image-api-images-123456789012
ECR Repository: 123456789012.dkr.ecr.us-east-1.amazonaws.com/alpha-image-api
```

---

## API Reference

### `POST /v1/generate`
Create a new image generation job.

**Headers**
```
Authorization: Bearer <API_KEY>
Content-Type: application/json
```

**Body**
```json
{
  "prompt": "A futuristic city floating in the sky",
  "reference_image_urls": []
}
```

**Response**
```json
{
  "jobId": "uuid",
  "statusUrl": "/v1/result/uuid"
}
```

---

### `GET /v1/result/:jobId`
Fetch status of a job.

**Response**
```json
{
  "id": "uuid",
  "status": "COMPLETED",
  "result_cloudfront_url": "https://dxxx.cloudfront.net/images/uuid/result.png"
}
```
---

## Monitoring & Logs
- **Local:** stdout logs for API + worker
- **AWS:** CloudWatch Log Groups `/ecs/chronicle-image-api/api` and `/ecs/chronicle-image-api/worker`
- **Metrics:** CloudWatch (SQS depth, ECS CPU/memory)
