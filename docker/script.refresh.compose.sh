#!/usr/bin/env bash

set -euo pipefail

dk_ps() {
  docker ps --no-trunc -a --format 'table {{.Names}}\n\t{{.Image}}\n\t{{.Status}}\n\t{{.Command}}\n\n' | tac
}

ENV=${ENV:-development}

save_canonical_compose_config() {
  dk_ps

  echo -e "\nforcing .env.${ENV}.compose.[yaml, json] in current dir"
  docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
  docker compose convert >.env.${ENV}.compose.yaml
}
service_restart_all() {
  echo -e "restarting all containers"
  docker compose up -d --force-recreate
  save_canonical_compose_config
}
service_restart() {
  service_name=$1
  rebuild_image=${2:-0}

  dk_up_flags='-d --force-recreate'

  if [ "$rebuild_image" == "1" ]; then
    echo 'also rebuilding container image'
    dk_up_flags="$dk_up_flags --build"
  fi

  docker compose up $dk_up_flags $service_name
  save_canonical_compose_config
}
cmd=${1:-'all'}
case $cmd in
all) service_restart_all ;;
*) service_restart "$@" ;;
esac
