#!/usr/bin/env bash
set -euo pipefail

url="${INFISICAL_URL:-https://app.infisical.com}"
client_id="${INFISICAL_CLIENT_ID:?defina INFISICAL_CLIENT_ID}"
client_secret="${INFISICAL_CLIENT_SECRET:?defina INFISICAL_CLIENT_SECRET}"

corpo="$(jq -n --arg id "$client_id" --arg segredo "$client_secret" '{clientId: $id, clientSecret: $segredo}')"
arquivo_resposta="$(mktemp)"
trap 'rm -f "$arquivo_resposta"' EXIT

if ! codigo="$(curl --silent --show-error --max-time 20 --retry 3 --retry-delay 2 \
  --output "$arquivo_resposta" --write-out '%{http_code}' \
  -X POST "${url%/}/api/v1/auth/universal-auth/login" \
  -H 'Content-Type: application/json' -d "$corpo" 2>/dev/null)"; then
  echo "Nao foi possivel contatar o Infisical em ${url} (rede ou URL incorreta)." >&2
  exit 1
fi

if [ "$codigo" != "200" ]; then
  motivo="$(jq -r '.message // .error // empty' "$arquivo_resposta" 2>/dev/null | head -c 300 || true)"
  echo "Falha ao autenticar no Infisical via Universal Auth (HTTP ${codigo}) em ${url}." >&2
  [ -z "$motivo" ] || echo "Motivo informado pelo Infisical: ${motivo}" >&2
  echo "Verifique: client id, client secret (so aparece uma vez ao criar) e a regiao/URL (INFISICAL_URL)." >&2
  exit 1
fi

token="$(jq -r '.accessToken // empty' "$arquivo_resposta")"
if [ -z "$token" ]; then
  echo "Resposta do Infisical sem accessToken." >&2
  exit 1
fi

if ! [[ "$token" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; then
  echo "Token do Infisical com caracteres inesperados." >&2
  exit 1
fi

printf '%s' "$token"
