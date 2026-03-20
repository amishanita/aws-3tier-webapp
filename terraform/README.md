# Terraform Notes

## Remote state (S3 + DynamoDB locking)

This repo uses Terraform backends configured per environment under:

- `terraform/environments/dev/backend.hcl`
- `terraform/environments/prod/backend.hcl`

Fill in:

- `bucket` with a real S3 bucket name
- `dynamodb_table` with a real DynamoDB table name

Then run (per environment):

```bash
cd terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform apply
```

## Variables you must provide

The ALB HTTPS listener requires an existing ACM certificate ARN:

- `acm_certificate_arn` (set in your Terraform variables / CI secrets)

Optionally, Secrets Manager rotation requires a rotation lambda ARN:

- `secrets_rotation_lambda_arn`

If you don't set it, the secret will still be created, but rotation won’t be configured.

## Alarm calculation notes

The “RDS connections over 80%” alarm uses an approximate `rds_max_connections` variable (since “max_connections” is a DB parameter and not directly modeled as a Terraform output).

## CI/CD integration points

GitHub Actions reads these Terraform outputs from the existing state:

- `ecr_repository_url`
- `codedeploy_app_name`
- `codedeploy_deployment_group_name`
- `codedeploy_artifacts_bucket`
- `ssm_image_uri_parameter_name`

So after changing infrastructure, make sure the remote state is up-to-date.

