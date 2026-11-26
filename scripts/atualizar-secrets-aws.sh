#!/usr/bin/env bash
set -euo pipefail

perfil="${AWS_PROFILE:-default}"
repositorio=""
simular=false
arquivo_credenciais="${AWS_SHARED_CREDENTIALS_FILE:-$HOME/.aws/credentials}"

uso() {
  cat <<'USO'
Uso: scripts/atualizar-secrets-aws.sh [--perfil NOME] [--repo DONO/REPO] [--simular]

Le as credenciais temporarias do Learner Lab em ~/.aws/credentials e grava no
GitHub Actions como AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY e AWS_SESSION_TOKEN.

  --perfil NOME     perfil do arquivo de credenciais (padrao: AWS_PROFILE ou "default")
  --repo DONO/REPO  repositorio de destino (padrao: o repositorio do diretorio atual)
  --simular         valida tudo, mas nao grava nada no GitHub
USO
}

while [ $# -gt 0 ]; do
  case "$1" in
    --perfil) perfil="${2:?--perfil exige um valor}"; shift 2 ;;
    --repo) repositorio="${2:?--repo exige um valor}"; shift 2 ;;
    --simular) simular=true; shift ;;
    -h | --help) uso; exit 0 ;;
    *) echo "Argumento desconhecido: $1" >&2; uso >&2; exit 2 ;;
  esac
done

for comando in gh aws awk; do
  command -v "$comando" >/dev/null || { echo "Comando ausente: $comando" >&2; exit 1; }
done

[ -f "$arquivo_credenciais" ] || { echo "Arquivo nao encontrado: $arquivo_credenciais" >&2; exit 1; }

ler_chave() {
  awk -F'=' -v perfil="$perfil" -v chave="$1" '
    { sub(/\r$/, "") }
    /^\[.*\]$/ { atual = substr($0, 2, length($0) - 2); next }
    atual == perfil {
      nome = $1; gsub(/[ \t]/, "", nome)
      if (nome == chave) {
        valor = substr($0, index($0, "=") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", valor)
        print valor
        exit
      }
    }
  ' "$arquivo_credenciais"
}

chave_acesso="$(ler_chave aws_access_key_id)"
chave_secreta="$(ler_chave aws_secret_access_key)"
token_sessao="$(ler_chave aws_session_token)"

if [ -z "$chave_acesso" ] || [ -z "$chave_secreta" ]; then
  echo "Perfil '$perfil' nao encontrado ou incompleto em $arquivo_credenciais" >&2
  exit 1
fi

if [ -z "$token_sessao" ]; then
  echo "Perfil '$perfil' nao tem aws_session_token: nao parece ser do Learner Lab." >&2
  echo "Abortando para nao enviar credenciais permanentes de outra conta ao GitHub." >&2
  exit 1
fi

if ! identidade="$(AWS_PROFILE="$perfil" aws sts get-caller-identity --query Arn --output text 2>/dev/null)"; then
  echo "As credenciais do perfil '$perfil' estao expiradas ou invalidas. Reinicie o lab e copie de novo." >&2
  exit 1
fi

case "$identidade" in
  *assumed-role/voclabs/*) ;;
  *)
    echo "O perfil '$perfil' nao pertence ao Learner Lab (identidade: ${identidade%%/*}/...). Abortando." >&2
    exit 1
    ;;
esac

if [ -z "$repositorio" ]; then
  repositorio="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

segredos=(
  "AWS_ACCESS_KEY_ID:$chave_acesso"
  "AWS_SECRET_ACCESS_KEY:$chave_secreta"
  "AWS_SESSION_TOKEN:$token_sessao"
)

for par in "${segredos[@]}"; do
  nome="${par%%:*}"
  valor="${par#*:}"
  if [ "$simular" = true ]; then
    echo "[simulacao] gravaria $nome (${#valor} caracteres) em $repositorio"
    continue
  fi
  printf '%s' "$valor" | gh secret set "$nome" --repo "$repositorio" >/dev/null
  echo "Atualizado: $nome em $repositorio"
done

if [ "$simular" = true ]; then
  echo "Simulacao concluida: nada foi gravado. Credenciais validas (conta do Learner Lab)."
else
  echo "Concluido. Os segredos expiram junto com a sessao do lab: repita este passo a cada novo Start Lab."
fi
