# 3-Tier HA Web Application on AWS (Terraform + CI/CD)

This repo contains a production-style 3-tier architecture:

- Web tier: Application Load Balancer (ALB) + Auto Scaling EC2
- Application tier: Flask API in a Docker container (ECR)
- Data tier: RDS MySQL (Multi-AZ) + ElastiCache Redis
- Security, secrets, and observability (WAF, Secrets Manager, CloudWatch)
- Fully automated delivery (GitHub Actions -> ECR -> CodeDeploy)

## What to build first

Per the project prompt, this repo is structured so **Terraform + CI/CD** work end-to-end first. Once that’s running, everything else (caching/observability/load testing) is layered on.

## Repo layout

- `terraform/`: infrastructure-as-code (dev + prod environments)
- `app/`: Flask API + Dockerfile
- `tests/load/`: load-testing scripts (k6)
- `scripts/`: bootstrap and CodeDeploy hooks
- `docs/`: architecture diagram + notes

## Prerequisites

- AWS credentials configured for Terraform and CI/CD (locally for `terraform`, and in GitHub via OIDC or secrets).
- Terraform CLI
- Docker CLI
- A domain certificate:
  - Provide an existing ACM certificate ARN in `terraform/environments/{dev,prod}/terraform.tfvars` OR
  - Extend the Terraform code to request/validate a certificate via Route 53.

## Deploy order (local)

1. Create the remote Terraform backend bucket + DynamoDB lock table (see `terraform/README.md`).
2. Deploy dev: `terraform init` then `terraform apply` in `terraform/environments/dev`
3. Deploy prod: `terraform init` then `terraform apply` in `terraform/environments/prod`
4. Push commits to `main` to trigger CI/CD:
   - lints and tests run
   - Docker image is built and pushed to ECR
   - CodeDeploy updates EC2 instances in staging, then gates prod

## Diagram

See `docs/architecture-diagram.mmd` for the architecture diagram.

## Engineering decisions (what/why)

### Terraform-first deployment

Infrastructure is built from code with separate `dev` and `prod` Terraform environments. Remote state is configured via S3 + DynamoDB locking so concurrent applies don’t corrupt state.

### Zero “console glue” for deployments

The ASG instances always read the current Docker image from a single SSM parameter (`ssm_image_uri_parameter_name`). CI/CD updates that parameter, then triggers CodeDeploy to restart the container using the same env configuration stored on the instance.

This design matters because:

- New instances launched during scale-out automatically pull the latest deployed image (no drift).
- CodeDeploy focuses on restart/redeploy, not on re-provisioning infrastructure.

### Security hardening

- Least-privilege security groups between ALB -> EC2 -> RDS/Redis.
- WAFv2 AWS managed rule groups attached to the ALB.
- Database and cache credentials stored in Secrets Manager (application runtime reads the secret at startup).
- ALB access logs written to an encrypted S3 bucket.

### Caching + load testing

The Flask API uses Redis as a read-through cache for the `/api/data` endpoint. On a cache miss it reads MySQL, writes to Redis with a TTL, and returns the value.

Invalidation strategy: TTL-based expiration (`CACHE_TTL_SECONDS`) with “cache-aside” (write to Redis on miss). For a write-heavy API, you’d also invalidate on updates (delete key or publish an invalidation event).

Load test results are expected to be captured during a k6 run (`tests/load/k6.js`) while watching both:

- Auto Scaling signal: `CPUUtilization` (ASG)
- Custom observability signal: `ApiResponseTimeMsAvg` and `CacheHitRate`

### CI/CD via GitHub Actions + CodeDeploy

GitHub Actions pipeline stages:

1. `lint` (ruff) -> `test` (pytest)
2. `docker build` -> `push` to ECR
3. Update per-environment SSM image URI parameter
4. Create a CodeDeploy deployment:
   - staging first
   - production waits for a manual approval gate (GitHub environment `production`)

### Required GitHub Secrets (for the workflow to run)

- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
- `DEV_ACM_CERT_ARN`, `PROD_ACM_CERT_ARN`

For a production-grade setup, swap these for GitHub Actions OIDC (no long-lived AWS keys).

## 5-minute interview walkthrough (script)

1. “This is a production-style 3-tier system: ALB + Auto Scaling EC2 in public/private subnets, Flask API in Docker, and RDS MySQL (Multi-AZ) with Redis in private subnets.”
2. “Terraform provisions everything: VPC, security groups, WAF, ALB listeners (HTTP->HTTPS redirect), ECR, ASG with a launch template, RDS + read replica, Redis, and Secrets Manager.”
3. “Observability isn’t an afterthought: the app emits structured JSON logs to CloudWatch Logs and publishes CloudWatch metrics like cache hit rate and API response time.”
4. “Auto scaling is driven by CPU plus a custom metric from the API, so scaling is tied to user-perceived latency.”
5. “CI/CD is end-to-end: GitHub Actions builds and pushes the image, updates an SSM parameter, and uses CodeDeploy to restart containers on the ASG with a safe deployment configuration.”
6. “Secrets stay in AWS: the app retrieves database credentials from Secrets Manager at runtime, and (optionally) rotation is configured for production-grade operations.”

## What I would do differently with more time

- Implement GitHub Actions OIDC to remove long-lived AWS credentials.
- Add blue/green deployment mechanics (where safe) and richer rollback evidence.
- Add ECS Fargate as a stretch modernization path (removing EC2 lifecycle concerns).
- Add a CI step that automatically exports CloudWatch dashboard widgets to artifacts after load tests.

## Load test results (expected deliverable)

After you run `k6` for each environment, capture:

- `TierHaWeb ApiResponseTimeMsAvg` (latency) while Auto Scaling adds capacity
- `CacheHitRate` (did caching reduce DB pressure?)
- A screenshot/export from the CloudWatch dashboard for the same time window

Document:

- How long it took to scale out (minutes)
- Whether latency stabilized as capacity increased

