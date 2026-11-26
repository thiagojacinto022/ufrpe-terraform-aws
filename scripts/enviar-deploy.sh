#!/usr/bin/env bash
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
projeto="${PROJECT_NAME:-webapp}"
ambiente="${ENVIRONMENT:-dev}"
regiao="${AWS_REGION:-us-east-1}"
tag="${1:?uso: enviar-deploy.sh <tag-da-imagem>}"
limite_segundos="${LIMITE_SEGUNDOS:-600}"

export AWS_DEFAULT_REGION="$regiao"

conta="$(aws sts get-caller-identity --query Account --output text)"
bucket="${projeto}-${ambiente}-tfstate-${conta}"
chave="deploy/${tag}.tar.gz"
pacote="$(mktemp -d)/deploy.tar.gz"

tar -czf "$pacote" -C "$raiz/deploy" .
aws s3 cp "$pacote" "s3://${bucket}/${chave}" --only-show-errors

instancias="$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=${projeto}-${ambiente}-web" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].InstanceId' --output text)"

if [ -z "$instancias" ] || [ "$(wc -w <<<"$instancias")" -ne 1 ]; then
  echo "Esperava exatamente 1 instancia ${projeto}-${ambiente}-web em execucao, encontrei: '${instancias}'" >&2
  exit 1
fi

status_ssm="$(aws ssm describe-instance-information \
  --filters "Key=InstanceIds,Values=${instancias}" \
  --query 'InstanceInformationList[0].PingStatus' --output text)"
if [ "$status_ssm" != "Online" ]; then
  echo "Instancia ${instancias} nao esta Online no SSM (status: ${status_ssm})" >&2
  exit 1
fi

comandos="$(jq -n \
  --arg bucket "$bucket" --arg chave "$chave" --arg tag "$tag" \
  '[
    "set -euo pipefail",
    "rm -rf /tmp/deploy-pacote && mkdir -p /tmp/deploy-pacote",
    "aws s3 cp s3://\($bucket)/\($chave) /tmp/deploy.tar.gz --only-show-errors",
    "tar -xzf /tmp/deploy.tar.gz -C /tmp/deploy-pacote",
    "bash /tmp/deploy-pacote/implantar.sh \($tag)"
  ] | {commands: .}')"

id_comando="$(aws ssm send-command \
  --instance-ids "$instancias" \
  --document-name AWS-RunShellScript \
  --comment "deploy ${tag}" \
  --timeout-seconds "$limite_segundos" \
  --parameters "$comandos" \
  --query 'Command.CommandId' --output text)"

echo "Deploy ${tag} enviado a ${instancias} (comando ${id_comando})"

fim=$((SECONDS + limite_segundos + 30))
sleep 5
while true; do
  situacao="$(aws ssm get-command-invocation --command-id "$id_comando" --instance-id "$instancias" \
    --query Status --output text 2>/dev/null || echo Pending)"
  case "$situacao" in
    Pending | InProgress | Delayed)
      [ "$SECONDS" -lt "$fim" ] || { echo "Tempo esgotado aguardando o deploy" >&2; exit 1; }
      sleep 5
      ;;
    *)
      break
      ;;
  esac
done

echo "----- saida do deploy -----"
aws ssm get-command-invocation --command-id "$id_comando" --instance-id "$instancias" \
  --query StandardOutputContent --output text
erros="$(aws ssm get-command-invocation --command-id "$id_comando" --instance-id "$instancias" \
  --query StandardErrorContent --output text)"
[ -z "$erros" ] || { echo "----- erros -----"; echo "$erros"; }

if [ "$situacao" != "Success" ]; then
  echo "Deploy falhou com status ${situacao}" >&2
  exit 1
fi
