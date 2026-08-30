#!/usr/bin/env bash
# Рендерит чарт во всех значимых конфигурациях и валидирует результат.
# Каждая комбинация — ветка шаблонов, в которой раньше находили баги.
set -euo pipefail

cd "$(dirname "$0")/.."
BASE=(--set seafile.serverHostname=seafile.example.com)

run() {
  local name="$1"; shift
  local out
  if ! out=$(helm template t . "${BASE[@]}" "$@" 2>&1); then
    echo "FAIL render [$name]"; echo "$out"; return 1
  fi
  # Признак того, что map попал в манифест как значение скаляра.
  if grep -q 'map\[' <<<"$out"; then
    echo "FAIL [$name]: в манифесте есть map["; return 1
  fi
  # FQDN с точкой на конце — след необъявленного clusterDomain.
  if grep -qE '^\s+(value|externalName): "[^"]*\.svc\.?"\s*$' <<<"$out"; then
    echo "FAIL [$name]: оборванный FQDN"; return 1
  fi
  if ! docker run --rm -i ghcr.io/yannh/kubeconform:latest-alpine \
        -strict -ignore-missing-schemas -summary <<<"$out"; then
    echo "FAIL kubeconform [$name]"; return 1
  fi
  echo "OK [$name]"
}

run "defaults"
run "ingress"        --set ingress.enabled=true --set ingress.host=seafile.example.com
run "ingress+tls"    --set ingress.enabled=true --set ingress.host=seafile.example.com \
                     --set ingress.tls.enabled=true --set ingress.tls.secretName=seafile-tls
run "webdav"         --set ingress.enabled=true --set ingress.host=seafile.example.com \
                     --set seafile.webdav.enabled=true
run "traefik"        --set ingress.enabled=true --set ingress.host=seafile.example.com \
                     --set ingress.className=traefik --set ingress.traefik.buffering=true
run "annotation-override" --set ingress.enabled=true --set ingress.host=seafile.example.com \
                          --set 'ingress.annotations.nginx\.ingress\.kubernetes\.io/proxy-body-size=64m'
run "external-db"    --set database.enabled=false --set database.host=db.example.com
run "external-cache" --set cache.enabled=false --set cache.host=redis.example.com
run "existing-secrets" --set seafile.existingSecret=s --set database.existingSecret=d \
                       --set cache.existingSecret=c
run "paused"         --set replicaCount=0

echo "все конфигурации прошли"
