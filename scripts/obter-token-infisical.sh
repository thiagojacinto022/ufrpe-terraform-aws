#!/usr/bin/env bash
set -euo pipefail

url="${INFISICAL_URL:-https://app.infisical.com}"
client_id="${INFISICAL_CLIENT_ID:?defina INFISICAL_CLIENT_ID}"
client_secret="${INFISICAL_CLIENT_SECRET:?defina INFISICAL_CLIENT_SECRET}"

corpo="$(jq -n --arg id "$client_id" --arg segredo "$client_secret" '{clientId: $id, clientSecret: $segredo}')"

if ! resposta="$(curl --silent --show-error --fail --max-time 20 --retry 3 --retry-delay 2 \
  -X POST "${url%/}/api/v1/auth/universal-auth/login" \
  -H 'Content-Type: application/json' -d "$corpo" 2>/dev/null)"; then
  echo "Falha ao autenticar no Infisical via Universal Auth (verifique client id/secret e a URL)." >&2
  exit 1
fi

token="$(jq -r '.accessToken // empty' <<<"$resposta")"
if [ -z "$token" ]; then
  echo "Resposta do Infisical sem accessToken." >&2
  exit 1
fi

if ! [[ "$token" =~ ^[A-Za-z0-9._~+/=-]+$ ]]; then
  echo "Token do Infisical com caracteres inesperados." >&2
  exit 1
fi

printf '%s' "$token"
