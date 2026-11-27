#!/usr/bin/env bash
set -euo pipefail

raiz="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repositorio=""
simular=false

uso() {
  cat <<'USO'
Uso: scripts/configurar-infisical-github.sh [--repo DONO/REPO] [--simular]

Pergunta o client id, o client secret (sem ecoar), o project id e o ambiente do Infisical,
VALIDA o login (Universal Auth) e a leitura dos 3 segredos no Infisical e, so entao, grava:
  secrets:   INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET
  variables: INFISICAL_PROJECT_ID, INFISICAL_ENV (e INFISICAL_URL, se informada)

Tambem aceita os valores prontos por ambiente: INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET,
INFISICAL_PROJECT_ID, INFISICAL_ENV e INFISICAL_URL.

  --repo DONO/REPO  repositorio de destino (padrao: o do diretorio atual)
  --simular         valida no Infisical, mas nao grava nada no GitHub
USO
}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repositorio="${2:?--repo exige um valor}"; shift 2 ;;
    --simular) simular=true; shift ;;
    -h | --help) uso; exit 0 ;;
    *) echo "Argumento desconhecido: $1" >&2; uso >&2; exit 2 ;;
  esac
done

for comando in gh jq curl; do
  command -v "$comando" >/dev/null || { echo "Comando ausente: $comando" >&2; exit 1; }
done
python_cmd=""
for candidato in python3 python; do
  if command -v "$candidato" >/dev/null && "$candidato" -c 'import sys' >/dev/null 2>&1; then
    python_cmd="$candidato"
    break
  fi
done
[ -n "$python_cmd" ] || { echo "Python funcional nao encontrado (python3 ou python)." >&2; exit 1; }

perguntar() {
  local variavel="$1" texto="$2" silencioso="${3:-false}" padrao="${4:-}"
  if [ -n "${!variavel:-}" ]; then
    return 0
  fi
  local valor
  if [ "$silencioso" = true ]; then
    read -r -s -p "$texto: " valor
    echo
  else
    read -r -p "$texto${padrao:+ [$padrao]}: " valor
  fi
  printf -v "$variavel" '%s' "${valor:-$padrao}"
}

perguntar INFISICAL_CLIENT_ID "Client ID da machine identity"
perguntar INFISICAL_CLIENT_SECRET "Client Secret da machine identity" true
perguntar INFISICAL_PROJECT_ID "Project ID"
perguntar INFISICAL_ENV "Slug do ambiente" false prod
INFISICAL_URL="${INFISICAL_URL:-}"

for variavel in INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET INFISICAL_PROJECT_ID INFISICAL_ENV; do
  [ -n "${!variavel}" ] || { echo "Valor vazio: ${variavel}" >&2; exit 1; }
done

export INFISICAL_CLIENT_ID INFISICAL_CLIENT_SECRET INFISICAL_PROJECT_ID INFISICAL_ENV
[ -z "$INFISICAL_URL" ] || export INFISICAL_URL

echo "1/3 Autenticando no Infisical (Universal Auth)..."
INFISICAL_ACCESS_TOKEN="$("$raiz/scripts/obter-token-infisical.sh")"
export INFISICAL_ACCESS_TOKEN
echo "    ok: login aceito."

echo "2/3 Lendo DB_PASSWORD, TOKEN_SECRET e GRAFANA_ADMIN_PASSWORD do projeto..."
temporario="$(mktemp -d)"
trap 'rm -rf "$temporario"' EXIT
"$python_cmd" -I "$raiz/deploy/buscar_segredos.py" "$temporario/segredos.env"
echo "    ok: os 3 segredos existem e estao em formato valido."
unset INFISICAL_ACCESS_TOKEN

if [ -z "$repositorio" ]; then
  repositorio="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

if [ "$simular" = true ]; then
  echo "3/3 [simulacao] nada foi gravado em $repositorio. Rode sem --simular para gravar."
  exit 0
fi

echo "3/3 Gravando no GitHub ($repositorio)..."
printf '%s' "$INFISICAL_CLIENT_ID" | gh secret set INFISICAL_CLIENT_ID --repo "$repositorio" >/dev/null
printf '%s' "$INFISICAL_CLIENT_SECRET" | gh secret set INFISICAL_CLIENT_SECRET --repo "$repositorio" >/dev/null
gh variable set INFISICAL_PROJECT_ID --repo "$repositorio" --body "$INFISICAL_PROJECT_ID" >/dev/null
gh variable set INFISICAL_ENV --repo "$repositorio" --body "$INFISICAL_ENV" >/dev/null
[ -z "$INFISICAL_URL" ] || gh variable set INFISICAL_URL --repo "$repositorio" --body "$INFISICAL_URL" >/dev/null

echo "Pronto. Proximo passo: gh workflow run \"CI/CD\" e confira 'Fonte dos segredos: Infisical' no log do deploy."
