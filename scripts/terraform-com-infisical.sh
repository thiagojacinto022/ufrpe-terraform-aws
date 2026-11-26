#!/usr/bin/env bash
set -euo pipefail

projeto_id="${INFISICAL_PROJECT_ID:?defina INFISICAL_PROJECT_ID}"
ambiente="${INFISICAL_ENV:-prod}"

command -v infisical >/dev/null || {
  echo "Infisical CLI ausente: https://infisical.com/docs/cli/overview" >&2
  exit 1
}

exec infisical run --projectId "$projeto_id" --env "$ambiente" -- bash -c '
  : "${DB_PASSWORD:?DB_PASSWORD nao veio do Infisical}"
  export TF_VAR_db_password="$DB_PASSWORD"
  unset DB_PASSWORD TOKEN_SECRET GRAFANA_ADMIN_PASSWORD
  exec terraform "$@"
' _ "$@"
