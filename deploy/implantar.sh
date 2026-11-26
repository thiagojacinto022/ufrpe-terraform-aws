#!/usr/bin/env bash
set -euo pipefail

tag="${1:?uso: implantar.sh <tag-da-imagem>}"
origem="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
base="/opt/termo"
espera_maxima="${ESPERA_MAXIMA:-150}"

falhar() {
  echo "ERRO: $*" >&2
  exit 1
}

aguardar_provisionamento() {
  for _ in $(seq 1 60); do
    [ -f "$base/.provisionado" ] && return 0
    sleep 5
  done
  falhar "instancia nao terminou o provisionamento inicial (user_data)"
}

carregar_ambiente() {
  set -a
  . "$base/infra.env"
  [ ! -f "$base/segredos.env" ] || . "$base/segredos.env"
  set +a
  export IMAGE_TAG="$1"
}

compose() {
  docker compose -p termo \
    -f "$1/docker-compose.prod.yml" \
    -f "$1/docker-compose.observabilidade.yml" \
    "${@:2}"
}

provisionar_segredos() {
  if [ -n "${INFISICAL_ACCESS_TOKEN:-}" ]; then
    python3 "$origem/buscar_segredos.py" "$base/segredos.env.novo"
    mv "$base/segredos.env.novo" "$base/segredos.env"
    chmod 600 "$base/segredos.env"
    unset INFISICAL_ACCESS_TOKEN
    echo "Fonte dos segredos: Infisical"
    return 0
  fi

  [ -f "$base/segredos.env" ] || falhar "sem token do Infisical e sem $base/segredos.env"
  echo "AVISO: token do Infisical nao informado; mantendo os segredos ja existentes na instancia" >&2
  echo "Fonte dos segredos: arquivo existente"
}

aguardar_saude() {
  local limite=$((SECONDS + espera_maxima))
  while [ "$SECONDS" -lt "$limite" ]; do
    if curl --fail --silent --max-time 5 http://127.0.0.1/health >/dev/null; then
      return 0
    fi
    sleep 5
  done
  return 1
}

voltar_versao_anterior() {
  [ -d "$base/anterior" ] || return 1
  [ -f "$base/tag_atual" ] || return 1

  local tag_anterior
  tag_anterior="$(cat "$base/tag_atual")"
  echo "Voltando para a versao anterior ($tag_anterior)" >&2
  rm -rf "$base/atual"
  mv "$base/anterior" "$base/atual"
  carregar_ambiente "$tag_anterior"
  compose "$base/atual" up -d --remove-orphans
}

aguardar_provisionamento
[ -f "$base/infra.env" ] || falhar "$base/infra.env ausente"

rm -rf "$base/novo"
mkdir -p "$base/novo"
cp -a "$origem"/. "$base/novo"/
rm -f "$base/novo/implantar.sh" "$base/novo/buscar_segredos.py"

carregar_ambiente "$tag"
docker pull "$ECR_BACKEND:$tag"
docker pull "$ECR_FRONTEND:$tag"

provisionar_segredos
carregar_ambiente "$tag"
compose "$base/novo" config --quiet

rm -rf "$base/anterior"
[ -d "$base/atual" ] && mv "$base/atual" "$base/anterior"
mv "$base/novo" "$base/atual"

compose "$base/atual" up -d --remove-orphans

if ! aguardar_saude; then
  compose "$base/atual" ps >&2 || true
  compose "$base/atual" logs --tail 50 backend frontend >&2 || true
  voltar_versao_anterior || true
  falhar "aplicacao nao ficou saudavel em ${espera_maxima}s"
fi

echo "$tag" > "$base/tag_atual"
compose "$base/atual" ps
docker image prune --force --filter "until=72h" >/dev/null
echo "Deploy concluido: $tag"
