#!/usr/bin/env bash

set -euo pipefail

ENV=${ENV:-development}

dk_ps() {
  docker ps --no-trunc -a --format 'table {{.Names}}\n\t{{.Image}}\n\t{{.Status}}\n\t{{.Command}}\n\n' | tac
}

down() {
  down_flags='--rmi all --volumes'
  service_name=${1:-''}
  if test -n "$service_name"; then
    down_flags="$up_flags $service_name"
  fi
  docker compose down $down_flags
}
up() {
  up_flags='-d --build --force-recreate --renew-anon-volumes'
  service_name=${1:-''}
  if test -n "$service_name"; then
    up_flags="$up_flags $service_name"
  fi

  dk_ps

  echo -e "forcing .env.${ENV}.compose.[yaml, json] in current dir"
  docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
  docker compose convert >.env.${ENV}.compose.yaml

  docker compose up $up_flags
}

# redundant: the env file is persisted to disk
# docker compose config

cmd=${1:-'all'}
case $cmd in
all)
  echo -e 'resetting compose infrastructure'
  down
  up
  ;;
*)
  service_name=${1:?'compose service name is required'}

  echo "restarting compose service $service_name"
  docker compose rm -f --stop --volumes $service_name || true
  up $service_name
  ;;
esac
