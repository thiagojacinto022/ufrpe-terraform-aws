#!/usr/bin/env bash
set -euo pipefail

base_url="${1:?uso: verificar-deploy.sh <url-base>, ex.: http://meu-alb.amazonaws.com}"
base_url="${base_url%/}"
tentativas="${TENTATIVAS:-24}"
espera="${ESPERA:-10}"
limite_requisicao="${LIMITE_REQUISICAO:-10}"
apelido="ci_${GITHUB_RUN_ID:-local}_$RANDOM"

requisitar() {
  curl --silent --show-error --fail --connect-timeout 5 --max-time "$limite_requisicao" "$@"
}

com_tentativas() {
  local descricao="$1"
  shift
  local saida
  for tentativa in $(seq 1 "$tentativas"); do
    if saida="$(requisitar "$@" 2>&1)"; then
      echo "ok: ${descricao} (tentativa ${tentativa})" >&2
      printf '%s' "$saida"
      return 0
    fi
    echo "aguardando: ${descricao} (tentativa ${tentativa}/${tentativas}): ${saida}" >&2
    sleep "$espera"
  done
  echo "FALHA: ${descricao} nao respondeu apos ${tentativas} tentativas" >&2
  return 1
}

exigir() {
  local descricao="$1" condicao="$2" json="$3"
  if ! jq -e "$condicao" <<<"$json" >/dev/null; then
    echo "FALHA: ${descricao}: resposta inesperada" >&2
    return 1
  fi
  echo "ok: ${descricao}" >&2
}

saude="$(com_tentativas "GET /health" "${base_url}/health")"
exigir "/health reporta banco ok" '.status == "ok" and .banco == "ok"' "$saude"

jogador="$(com_tentativas "POST /api/jogadores" -X POST "${base_url}/api/jogadores" \
  -H 'Content-Type: application/json' -d "{\"apelido\":\"${apelido}\"}")"
exigir "jogador recebeu token" '.token | length > 20' "$jogador"
token="$(jq -r .token <<<"$jogador")"
[ "${GITHUB_ACTIONS:-}" != "true" ] || echo "::add-mask::${token}"

partida="$(com_tentativas "POST /api/partidas" -X POST "${base_url}/api/partidas" \
  -H "Authorization: Bearer ${token}")"
exigir "partida criada com 6 tentativas e sem revelar a palavra" \
  '.tentativas_restantes == 6 and (has("palavra") | not)' "$partida"
id_partida="$(jq -r .id <<<"$partida")"

palpite="$(com_tentativas "POST /api/partidas/{id}/palpites" -X POST \
  "${base_url}/api/partidas/${id_partida}/palpites" \
  -H "Authorization: Bearer ${token}" -H 'Content-Type: application/json' \
  -d '{"palavra":"termo"}')"
exigir "palpite avaliado letra a letra" \
  '(.palpite.letras | length == 5) and ([.palpite.letras[].estado] | all(. == "correta" or . == "presente" or . == "ausente"))' \
  "$palpite"

ranking="$(com_tentativas "GET /api/ranking" "${base_url}/api/ranking")"
exigir "ranking e uma lista" 'type == "array"' "$ranking"

metricas_status="$(curl --silent --output /dev/null --write-out '%{http_code}' --max-time "$limite_requisicao" "${base_url}/metrics" || true)"
if [ "$metricas_status" = "200" ]; then
  echo "FALHA: /metrics esta exposto publicamente pelo ALB" >&2
  exit 1
fi
echo "ok: /metrics nao e publico (HTTP ${metricas_status})"

echo "Verificacao pos-deploy concluida com sucesso em ${base_url}"
