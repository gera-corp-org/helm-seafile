#!/usr/bin/env bash
# Renders the chart in every significant configuration and validates the
# output. Each combination is a template branch where bugs were found before.
set -euo pipefail

cd "$(dirname "$0")/.."
BASE=(--set seafile.serverHostname=seafile.example.com)

run() {
  local name="$1"; shift
  local out
  if ! out=$(helm template t . "${BASE[@]}" "$@" 2>&1); then
    echo "FAIL render [$name]"; echo "$out"; return 1
  fi
  # Sign that a map ended up in the manifest as a scalar value.
  if grep -q 'map\[' <<<"$out"; then
    echo "FAIL [$name]: manifest contains map["; return 1
  fi
  # FQDN ending in a dot — trace of an undeclared clusterDomain.
  if grep -qE '^\s+(value|externalName): "[^"]*\.svc\.?"\s*$' <<<"$out"; then
    echo "FAIL [$name]: truncated FQDN"; return 1
  fi
  # Any secret the pod references via secretKeyRef must actually exist in
  # the output. kubeconform validates each document in isolation and won't
  # catch this — a chart-component secret (t-seafile[-mariadb|-redis]) could
  # be gated behind a wrong condition and fail to render, while the pod
  # would still reference it. Names that don't match this pattern are a
  # third-party existingSecret, deliberately absent from the output.
  local declared referenced ref
  declared=$(awk '/^kind: Secret$/{f=1} f && /^  name: /{print $2; f=0}' <<<"$out" | sort -u)
  referenced=$(awk '/secretKeyRef:/{f=1; next} f && /name: /{print $2; f=0}' <<<"$out" | sort -u)
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    if [[ "$ref" =~ ^t-seafile(-mariadb|-redis)?$ ]] && ! grep -qxF "$ref" <<<"$declared"; then
      echo "FAIL [$name]: pod references secret $ref, which is missing from the output"; return 1
    fi
  done <<<"$referenced"
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
run "external-db+cache" --set database.enabled=false --set database.host=db.example.com \
                        --set cache.enabled=false --set cache.host=redis.example.com
run "memcached"      --set cache.provider=memcached --set cache.host=mc.example.com
run "existing-secrets" --set seafile.existingSecret=s --set database.existingSecret=d \
                       --set cache.existingSecret=c
run "db-subpath"       --set database.persistence.subPath=data
run "paused"         --set replicaCount=0

echo "all configurations passed"
