#!/bin/bash
set -euo pipefail

REGION="${aws_region}"
APP_PORT="${app_port}"
ALB_HEALTH_PATH="${health_path}"

ECR_IMAGE_URI="$(aws ssm get-parameter --name "${ssm_image_param}" --region "${REGION}" --query 'Parameter.Value' --output text)"

# Ensure docker is available.
if ! command -v docker >/dev/null 2>&1; then
  if command -v dnf >/dev/null 2>&1; then
    sudo dnf update -y
    sudo dnf install -y docker
  else
    sudo yum update -y
    sudo yum install -y docker
  fi
fi

sudo systemctl enable docker || true
sudo systemctl start docker || true

# Authenticate to ECR for docker pulls.
aws ecr get-login-password --region "${REGION}" | sudo docker login --username AWS --password-stdin "${ecr_registry}"

CONTAINER_NAME="tier-ha-web-api"
LOG_GROUP="${log_group_name}"

# Persist app env for CodeDeploy updates.
sudo mkdir -p /etc/tier-ha-web
cat <<EOF | sudo tee /etc/tier-ha-web/app.env >/dev/null
DB_SECRET_ARN=${db_secret_arn}
REDIS_ENDPOINT=${redis_endpoint}
METRICS_NAMESPACE=${metric_namespace}
CACHE_TTL_SECONDS=${cache_ttl_seconds}
APP_PORT=${APP_PORT}
LOG_GROUP=${log_group_name}
SSM_IMAGE_URI_PARAMETER=${ssm_image_param}
EOF

# Retry image pulls until CI pushes the first image.
for i in $(seq 1 40); do
  if sudo docker pull "${ECR_IMAGE_URI}"; then
    break
  fi
  sleep 15
done

set +e
sudo docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1
set -e

sudo docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart=always \
  --log-driver=awslogs \
  --log-opt awslogs-region="${REGION}" \
  --log-opt awslogs-group="${LOG_GROUP}" \
  --log-opt awslogs-stream="$(curl -s http://169.254.169.254/latest/meta-data/instance-id || hostname)" \
  -p "${APP_PORT}:${APP_PORT}" \
  -e "AWS_REGION=${REGION}" \
  -e "DB_SECRET_ARN=${db_secret_arn}" \
  -e "REDIS_ENDPOINT=${redis_endpoint}" \
  -e "METRICS_NAMESPACE=${metric_namespace}" \
  -e "CACHE_TTL_SECONDS=${cache_ttl_seconds}" \
  "${ECR_IMAGE_URI}"

