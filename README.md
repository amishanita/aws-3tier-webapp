# 3-Tier HA Web Application on AWS | AWS 3層 高可用性 Web アプリケーション

> Production-style 3-tier architecture built with Terraform and full CI/CD automation.
> TerraformとCI/CDの完全自動化で構築した、プロダクションレベルの3層Webアプリケーション。

![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazonaws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-000000?style=flat&logo=flask&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-2496ED?style=flat&logo=docker&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?style=flat&logo=python&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-2088FF?style=flat&logo=githubactions&logoColor=white)

---

## Architecture Overview | アーキテクチャ概要

| Layer / レイヤー | Technology / 技術 |
|---|---|
| Web Tier / Web層 | ALB + Auto Scaling EC2 (Multi-AZ) |
| App Tier / アプリ層 | Python Flask + Docker + ECR |
| Data Tier / データ層 | RDS MySQL Multi-AZ + ElastiCache Redis |
| Infrastructure / インフラ | Terraform (dev + prod environments) |
| CI/CD | GitHub Actions → ECR → CodeDeploy |
| Security / セキュリティ | WAFv2 + Secrets Manager + Least-privilege SGs |
| Observability / 監視 | CloudWatch Logs + Custom Metrics + Alarms + SNS |

---

## What This Project Proves | このプロジェクトで証明できること

- **Production architecture patterns** — not a tutorial clone. Every decision is documented and justified.
- **Infrastructure as Code** — zero console clicking. Everything is reproducible from Terraform.
- **Secure by default** — credentials never hardcoded, WAF on the ALB, least-privilege security groups throughout.
- **Observable system** — structured JSON logs, custom CloudWatch metrics (cache hit rate, API response time), alarms with SNS alerts.
- **Automated delivery** — GitHub Actions pipeline with lint, test, build, push to ECR, and CodeDeploy with a manual prod approval gate.

---

> - **プロダクションアーキテクチャパターン** — チュートリアルの模倣ではなく、すべての設計判断を文書化・説明しています。
> - **Infrastructure as Code** — コンソール操作ゼロ。Terraformで完全に再現可能な構成です。
> - **セキュリティ優先設計** — 認証情報のハードコードなし、ALBにWAF適用、全レイヤーで最小権限のセキュリティグループ。
> - **可観測性** — 構造化JSONログ、カスタムCloudWatchメトリクス（キャッシュヒット率・APIレスポンスタイム）、SNSアラーム。
> - **自動デリバリー** — Lint・テスト・ビルド・ECRプッシュ・本番手動承認ゲート付きのGitHub Actionsパイプライン。

---

## Repository Structure | リポジトリ構成

```
aws-3tier-webapp/
├── .github/
│   └── workflows/
│       └── ci.yml          # CI/CD pipeline (lint → test → build → deploy)
├── app/
│   ├── main.py             # Flask API with Redis caching + CloudWatch metrics
│   ├── wsgi.py             # Gunicorn entry point
│   ├── requirements.txt
│   └── requirements-dev.txt
├── terraform/
│   ├── environments/
│   │   ├── dev/            # Dev environment (separate state)
│   │   └── prod/           # Prod environment (separate state)
│   └── modules/            # Reusable Terraform modules
├── tests/
│   ├── test_health.py      # Unit tests (pytest)
│   └── load/
│       └── k6.js           # Load test script
├── docs/
│   └── architecture-diagram.mmd
├── scripts/
│   └── codedeploy/         # CodeDeploy lifecycle hooks
├── Dockerfile
└── README.md
```

---

## Prerequisites | 事前準備

**English:**
- AWS account with credentials configured (`~/.aws/credentials` or environment variables)
- Terraform CLI installed
- Docker CLI installed
- GitHub account with Actions enabled
- An ACM certificate ARN for your domain (for HTTPS on the ALB)

**日本語:**
- AWSアカウントと認証情報の設定（`~/.aws/credentials` または環境変数）
- Terraform CLIのインストール
- Docker CLIのインストール
- GitHub Actionsが有効なGitHubアカウント
- ALBのHTTPS用ACM証明書ARN

---

## Deploy Order | デプロイ手順

### Local deployment | ローカルデプロイ

**1. Set up Terraform remote state backend**
```bash
# Create S3 bucket for state storage
aws s3 mb s3://your-terraform-state-bucket --region us-east-1

# Create DynamoDB table for state locking
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
```

**2. Deploy dev environment**
```bash
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform apply
```

**3. Deploy prod environment**
```bash
cd terraform/environments/prod
terraform init -backend-config=backend.hcl
terraform apply
```

**4. Trigger CI/CD**
```bash
git push origin main
# GitHub Actions runs: lint → test → docker build → push ECR → CodeDeploy staging → approval gate → prod
```

---

## Engineering Decisions | 設計判断

### Terraform-first | Terraform優先設計

Infrastructure is built entirely from code with separate `dev` and `prod` environments. Remote state is stored in S3 with DynamoDB locking so concurrent applies never corrupt state.

インフラはすべてコードで定義し、`dev`と`prod`を分離しています。リモートステートをS3+DynamoDBロックで管理することで、並行実行時のstate破損を防ぎます。

---

### Zero console glue | コンソール操作ゼロ

ASG instances always pull the current Docker image from a single SSM parameter (`ssm_image_uri_parameter_name`). CI/CD updates that parameter, then CodeDeploy restarts the container. This means:

- New instances launched during scale-out automatically use the latest image — no drift.
- CodeDeploy handles restart/redeploy only, not infrastructure provisioning.

ASGインスタンスは常にSSMパラメータからDockerイメージURIを取得します。CI/CDがパラメータを更新し、CodeDeployがコンテナを再起動します。これにより：

- スケールアウト時の新インスタンスも自動的に最新イメージを使用（ドリフトなし）。
- CodeDeployは再起動のみを担当し、インフラの再プロビジョニングは行いません。

---

### Security hardening | セキュリティ強化

- Least-privilege security groups: ALB → EC2 → RDS/Redis (no direct public access to data tier)
- WAFv2 AWS managed rule groups attached to the ALB
- Database and Redis credentials stored in Secrets Manager — app reads at runtime, never at build time
- ALB access logs written to an encrypted S3 bucket

- 最小権限セキュリティグループ：ALB → EC2 → RDS/Redis（データ層への直接パブリックアクセスなし）
- ALBにWAFv2マネージドルールグループを適用
- DB・Redis認証情報はSecrets Managerで管理 — ビルド時ではなく実行時に取得
- ALBアクセスログを暗号化S3バケットに保存

---

### Caching strategy | キャッシュ戦略

The Flask API uses Redis as a read-through cache for `/api/data`. On a cache miss it reads MySQL, writes to Redis with a TTL, and returns the value.

Invalidation: TTL-based expiration (`CACHE_TTL_SECONDS`) with cache-aside pattern. For write-heavy workloads, invalidate on update by deleting the Redis key or publishing an invalidation event.

Flask APIは`/api/data`エンドポイントにRedisのリードスルーキャッシュを使用しています。キャッシュミス時はMySQLから読み取り、TTL付きでRedisに書き込みます。

無効化戦略：TTLベースの有効期限（`CACHE_TTL_SECONDS`）とキャッシュアサイドパターン。書き込みの多いワークロードでは、Redisキーを削除するか無効化イベントを発行します。

---

### CI/CD pipeline | CI/CDパイプライン

```
push to main
    ↓
lint (ruff) + test (pytest)
    ↓
docker build + push to ECR
    ↓
update SSM image URI parameter
    ↓
CodeDeploy → staging
    ↓
manual approval gate (GitHub Environment: production)
    ↓
CodeDeploy → production
```

Required GitHub Secrets | 必要なGitHub Secrets:
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
- `DEV_ACM_CERT_ARN`, `PROD_ACM_CERT_ARN`

> For production: replace static keys with GitHub Actions OIDC for keyless authentication.
> 本番環境では：静的キーをGitHub Actions OIDCに置き換えて、キーレス認証を実現してください。

---

## Observability | 可観測性

The app publishes custom CloudWatch metrics every 30 seconds:

アプリは30秒ごとにカスタムCloudWatchメトリクスを送信します：

| Metric / メトリクス | Description / 説明 |
|---|---|
| `CacheHitRate` | Redis cache hit percentage / Redisキャッシュヒット率 |
| `ApiResponseTimeMsAvg` | Average API response time / 平均APIレスポンスタイム |
| `ApiErrors` | Count of 500 errors / 500エラー数 |

CloudWatch Alarms trigger SNS notifications when:
- CPU > 70%
- Error rate > 5%
- RDS connections > 80% of max

---

## Load Test Results | 負荷テスト結果

Run the k6 load test against your deployed environment:

```bash
BASE_URL=https://your-alb-dns k6 run tests/load/k6.js
```

Capture and document:
- `ApiResponseTimeMsAvg` during Auto Scaling scale-out
- `CacheHitRate` — did Redis reduce DB pressure?
- CloudWatch dashboard screenshot during the test window
- Time to scale out (minutes)
- Whether latency stabilized as new instances came online

負荷テストの実行後、以下を記録してください：
- スケールアウト中の`ApiResponseTimeMsAvg`
- `CacheHitRate` — RedisがDBの負荷を軽減しているか
- テスト中のCloudWatchダッシュボードのスクリーンショット
- スケールアウトにかかった時間（分）
- 新インスタンス追加後のレイテンシの安定化

> Results will be added here after load testing is complete.
> 負荷テスト完了後、結果をここに追記します。

---

## 5-Minute Interview Walkthrough | 5分間面接説明スクリプト

1. "This is a production-style 3-tier system: ALB + Auto Scaling EC2 in public/private subnets, Flask API in Docker, and RDS MySQL Multi-AZ with Redis — all in private subnets."
2. "Terraform provisions everything from scratch: VPC, security groups, WAF, ALB with HTTP→HTTPS redirect, ECR, ASG launch template, RDS with read replica, Redis, and Secrets Manager."
3. "Observability is built in: structured JSON logs ship to CloudWatch Logs, and the app publishes custom metrics — cache hit rate and API response time — every 30 seconds."
4. "Auto Scaling triggers on CPU plus the custom API latency metric, so scaling is tied to what users actually experience."
5. "CI/CD is fully automated: GitHub Actions builds and pushes the Docker image, updates an SSM parameter, and CodeDeploy rolls it out to staging, then prod behind a manual approval gate."
6. "Secrets never leave AWS: credentials are fetched from Secrets Manager at runtime. The app never sees them at build time."

---

## What I Would Do Differently | 改善点・反省点

- Replace static AWS keys with **GitHub Actions OIDC** — no long-lived credentials in GitHub Secrets.
- Add **blue/green deployment** via CodeDeploy for zero-downtime releases with clean rollback evidence.
- Migrate app tier to **ECS Fargate** to remove EC2 lifecycle management overhead.
- Add a CI step that **auto-exports CloudWatch dashboard screenshots** to GitHub Actions artifacts after each load test run.
- Implement **AWS Config rules** to detect and alert on infrastructure drift.

---

- 静的AWSキーを**GitHub Actions OIDC**に置き換え — GitHub Secretsに長期認証情報を保存しない。
- **ブルー/グリーンデプロイ**をCodeDeployで実装 — ゼロダウンタイムリリースとロールバック証跡。
- アプリ層を**ECS Fargate**に移行 — EC2のライフサイクル管理を排除。
- 負荷テスト実行後にCloudWatchダッシュボードのスクリーンショットを**GitHub Actions artifactsに自動エクスポート**するCIステップを追加。
- **AWS Configルール**でインフラドリフトを検知・アラート。

---

## Author | 作者

**amishanita** — [@amishanita](https://github.com/amishanita)


