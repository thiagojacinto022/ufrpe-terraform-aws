#!/usr/bin/env bash
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
projeto="${PROJECT_NAME:-webapp}"
ambiente="${ENVIRONMENT:-dev}"
regiao="${AWS_REGION:-us-east-1}"
incluir_state=false
somente_state=false
confirmado=false

uso() {
  cat <<'USO'
Uso: scripts/destruir.sh [--incluir-state] [--somente-state] [--sim]

Sem opcoes: destroi a infraestrutura da aplicacao (ALB, EC2, RDS, ECR, rede, SGs),
mantendo o bucket de state para recriar tudo depois.

  --incluir-state   alem da infraestrutura, esvazia (todas as versoes) e apaga o bucket de state
  --somente-state   apaga apenas o bucket de state (a infraestrutura precisa ja estar destruida)
  --sim             nao pede confirmacao interativa
USO
}

while [ $# -gt 0 ]; do
  case "$1" in
    --incluir-state) incluir_state=true; shift ;;
    --somente-state) incluir_state=true; somente_state=true; shift ;;
    --sim) confirmado=true; shift ;;
    -h | --help) uso; exit 0 ;;
    *) echo "Argumento desconhecido: $1" >&2; uso >&2; exit 2 ;;
  esac
done

export AWS_DEFAULT_REGION="$regiao"

if ! conta="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  echo "Credenciais AWS ausentes ou expiradas. Atualize o ~/.aws/credentials do Learner Lab." >&2
  exit 1
fi

bucket="${projeto}-${ambiente}-tfstate-${conta}"

confirmar() {
  [ "$confirmado" = true ] && return 0
  echo "Conta: ${conta} | projeto: ${projeto}-${ambiente} | regiao: ${regiao}"
  [ "$somente_state" = true ] || echo "Sera DESTRUIDA toda a infraestrutura da aplicacao (inclui o banco de dados e seus dados)."
  [ "$incluir_state" = false ] || echo "Sera APAGADO o bucket de state ${bucket} com todas as versoes."
  read -r -p "Digite 'destruir' para continuar: " resposta
  [ "$resposta" = "destruir" ] || { echo "Cancelado."; exit 1; }
}

destruir_infraestrutura() {
  cd "$raiz"
  export TF_VAR_db_password="${TF_VAR_db_password:-SenhaApenasParaDestruir0000}"
  ./scripts/iniciar-terraform.sh -input=false
  terraform destroy -input=false -auto-approve
}

esvaziar_bucket() {
  local pagina
  while true; do
    pagina="$(aws s3api list-object-versions --bucket "$bucket" --max-items 500 --output json)"
    local lote
    lote="$(jq -c '{Objects: ([(.Versions // [])[], (.DeleteMarkers // [])[]] | map({Key: .Key, VersionId: .VersionId})), Quiet: true}' <<<"$pagina")"
    [ "$(jq '.Objects | length' <<<"$lote")" -gt 0 ] || break
    aws s3api delete-objects --bucket "$bucket" --delete "$lote" >/dev/null
  done
}

apagar_state() {
  if ! aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    echo "Bucket ${bucket} nao existe; nada a apagar."
    return 0
  fi
  esvaziar_bucket
  aws s3api delete-bucket --bucket "$bucket"
  echo "Bucket ${bucket} apagado."
  echo "Remova tambem o state local do bootstrap: rm -rf bootstrap/terraform.tfstate* bootstrap/.terraform"
}

confirmar
[ "$somente_state" = true ] || destruir_infraestrutura
[ "$incluir_state" = false ] || apagar_state
echo "Concluido."
