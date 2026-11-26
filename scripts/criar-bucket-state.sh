#!/usr/bin/env bash
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
projeto="${PROJECT_NAME:-webapp}"
ambiente="${ENVIRONMENT:-dev}"
regiao="${AWS_REGION:-us-east-1}"

if ! conta="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  echo "Credenciais AWS ausentes ou expiradas. Atualize o ~/.aws/credentials do Learner Lab." >&2
  exit 1
fi

bucket="${projeto}-${ambiente}-tfstate-${conta}"

if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
  echo "Bucket $bucket já existe."
elif [ "$regiao" = "us-east-1" ]; then
  aws s3api create-bucket --bucket "$bucket" --region "$regiao" >/dev/null
  echo "Bucket $bucket criado."
else
  aws s3api create-bucket --bucket "$bucket" --region "$regiao" \
    --create-bucket-configuration "LocationConstraint=${regiao}" >/dev/null
  echo "Bucket $bucket criado."
fi

cd "$raiz/bootstrap"
terraform init -input=false
terraform apply -input=false \
  -var "project_name=${projeto}" -var "environment=${ambiente}" -var "aws_region=${regiao}" "$@"
