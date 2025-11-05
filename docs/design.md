# System Design — Image Generation API
---

## 1. Problem Statement

Design and implement a scalable API that:
- Accepts **text prompts** (and optional reference images),
- Generates corresponding images asynchronously,
- Returns a **permanent, shareable CDN URL**, and
- Can scale to handle **thousands of concurrent generation requests**.

Key goals:
- Fast and responsive API (no long waits for users)
- Reliable and scalable backend
- Secure, production-ready infrastructure

---

## 2. High-Level Architecture

```
+----------------------+       +------------------------+       +----------------------+
|   Client (Frontend)  | --->  |  API (Fastify + ECS)   | --->  |   SQS (Job Queue)    |
+----------------------+       +------------------------+       +----------------------+
                                        |                                 |
                                        |                                 v
                                        |                       +----------------------+
                                        |                       |   Worker (ECS)       |
                                        |                       |  - Consume Jobs      |
                                        |                       |  - Generate Images   |
                                        |                       +----------------------+
                                        |                                 |
                                        |                                 v
                                        |                       +----------------------+
                                        |                       | S3 (Image Storage)   |
                                        |                       +----------------------+
                                        |                                 |
                                        |                                 v
                                        |                       +----------------------+
                                        |                       | CloudFront (CDN)     |
                                        |                       +----------------------+
                                        |
                                        +--> PostgreSQL (RDS) for Job metadata
```
## 3.  Component Overview

| Component | Description | AWS Service |
|------------|--------------|-------------|
| API Layer | Receives generation requests, validates auth, creates job record, enqueues to SQS | ECS Fargate Service |
| Queue | Decouples request handling from heavy processing | Amazon SQS |
| Worker Service | Consumes SQS, generates image, uploads to S3, updates DB | ECS Fargate Service |
| Storage | Stores image files securely | S3 (private bucket, SSE-KMS) |
| CDN | Serves public image URLs | CloudFront |
| Database | Stores job metadata, status, timestamps, URLs | RDS (PostgreSQL) |
| Infrastructure | Provisioning, roles, networking | Terraform (IaC) |

---

## 4.  Detailed Flow

### 4.1 Request Flow
1. Client calls `POST /v1/generate` with  
   `{ "prompt": "A red cat playing guitar" }`
2. API validates request → creates a new `Job` record in DB with status `PENDING`.
3. Job is pushed into SQS queue with jobId and prompt.
4. API responds immediately with  
   `{ "jobId": "1234", "statusUrl": "/v1/result/1234" }`.

### 4.2 Worker Flow
1. Worker long-polls SQS for messages.
2. For each job:
    - Fetch metadata from DB.
    - Generate image via provider (mock or OpenAI API).
    - Upload to S3 as `images/{jobId}/result.png`.
    - Update job status to `COMPLETED` with CloudFront URL.
3. Delete message from SQS (acknowledge completion).

### 4.3 Result Fetch
- Client polls `/v1/result/:jobId`.
- API returns latest job status and `result_cloudfront_url` if ready.

## 5.  Infrastructure Design

### 5.1 Core AWS Services

| Service | Purpose |
|----------|----------|
| ECS (Fargate) | Runs API and Worker containers without managing servers. |
| ECR | Stores built Docker images. |
| SQS | Message queue for decoupling workloads. |
| S3 | Storage for generated images (encrypted). |
| CloudFront | CDN layer for serving public URLs efficiently. |
| RDS (PostgreSQL) | Persistent metadata storage. |
| Secrets Manager | Stores DB credentials and API keys. |
| CloudWatch | Logs, metrics, alarms for observability. |
| IAM | Scoped permissions for ECS tasks, S3, and SQS. |

### 5.2 Networking
- VPC with 3 public and 3 private subnets.
- Application Load Balancer for public HTTPS traffic.
- ECS tasks run in private subnets behind NAT gateways.
- RDS, S3, and SQS are private (no public access).

---

## 6.  Design Choices & Trade-offs

| Decision | Choice | Reason |
|-----------|--------|--------|
| Compute | ECS Fargate | Long-running, CPU-intensive workloads unsuitable for Lambda; no infra management overhead. |
| Queueing | SQS | Simple, reliable, supports DLQs, easy to autoscale ECS workers. |
| Database | PostgreSQL via RDS | Relational structure fits job tracking; Prisma ORM simplifies schema. |
| Storage | S3 + CloudFront | Cheap, scalable, secure permanent URLs. |
| IaC | Terraform | Reproducible, modular infra, portable between environments. |
| API Framework | Fastify | Lightweight, modern, TypeScript-friendly. |
| ORM | Prisma | Strong typing, quick migrations, developer productivity. |
| Local Testing | Docker Compose + LocalStack | Full AWS simulation for safe, cost-free development. |

## 7.  Scalability & Performance

| Area | Strategy |
|-------|-----------|
| API scaling | ECS Service Auto Scaling based on CPU or request volume. |
| Worker scaling | Scale on SQS queue depth via CloudWatch alarms. |
| Storage | S3 scales automatically; lifecycle rules manage retention. |
| Database | RDS Multi-AZ with read replicas for heavy read load. |
| Networking | NAT Gateway and VPC endpoints for private AWS traffic. |
| CDN performance | CloudFront edge caching, signed URLs if needed. |

---

## 8.  Security & Compliance

| Concern | Implementation |
|----------|----------------|
| Data access | IAM roles with least privilege for ECS tasks. |
| Network isolation | Private subnets, no public DB or S3 access. |
| Encryption | S3 SSE-KMS, HTTPS (ACM), Secrets Manager for credentials. |
| Authentication | API key-based auth for simplicity; can extend to JWT or Cognito. |
| Compliance | Terraform-managed infrastructure for auditability and consistency. |

---

## 9.  Reliability & Fault Tolerance

- At-least-once processing via SQS; worker is idempotent to avoid duplication.
- Dead Letter Queue (DLQ) captures failed jobs for reprocessing or analysis.
- Retry logic with exponential backoff for transient image-generation errors.
- RDS snapshots and S3 versioning ensure data durability.
- CloudWatch alarms trigger scaling or notifications on anomalies.
- Stateless ECS tasks enable rolling deployments and zero downtime updates.
