#!/bin/bash
set -euo pipefail

REGION="$(curl -s http://169.254.169.254/latest/meta-data/placement/region || true)"
if [ -z "$REGION" ]; then
  REGION="${AWS_REGION:-us-east-1}"
fi

if [ ! -f /etc/tier-ha-web/app.env ]; then
  echo "Missing /etc/tier-ha-web/app.env"
  exit 1
fi

# shellcheck disable=SC1091
source /etc/tier-ha-web/app.env

CONTAINER_NAME="tier-ha-web-api"

INSTANCE_ID="$(curl -s http://169.254.169.254/latest/meta-data/instance-id || hostname)"

IMAGE_URI="$(aws ssm get-parameter --name "$SSM_IMAGE_URI_PARAMETER" --region "$REGION" --query 'Parameter.Value' --output text)"
ECR_REGISTRY_HOST="$(echo "$IMAGE_URI" | cut -d/ -f1)"

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY_HOST"
docker pull "$IMAGE_URI"

docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart=always \
  --log-driver=awslogs \
  --log-opt awslogs-region="$REGION" \
  --log-opt awslogs-group="$LOG_GROUP" \
  --log-opt awslogs-stream="$INSTANCE_ID" \
  -p "${APP_PORT}:${APP_PORT}" \
  -e "AWS_REGION=${REGION}" \
  -e "DB_SECRET_ARN=${DB_SECRET_ARN}" \
  -e "REDIS_ENDPOINT=${REDIS_ENDPOINT}" \
  -e "METRICS_NAMESPACE=${METRICS_NAMESPACE}" \
  -e "CACHE_TTL_SECONDS=${CACHE_TTL_SECONDS}" \
  "$IMAGE_URI"

