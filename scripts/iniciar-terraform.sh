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

if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
  echo "Bucket de state '$bucket' não existe. Rode primeiro: cd bootstrap && terraform init && terraform apply" >&2
  exit 1
fi

cd "$raiz"
terraform init -reconfigure \
  -backend-config="bucket=${bucket}" \
  -backend-config="region=${regiao}" \
  "$@"
