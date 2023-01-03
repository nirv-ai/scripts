#!/usr/bin/env bash

set -euo pipefail

###########################
# refreshes a container
# for something more destructive, use reset script
###########################

# @see bookOfNoah
dk_ps() {
  docker ps --no-trunc -a --format 'table {{.Names}}\n\t{{.Image}}\n\t{{.Status}}\n\t{{.Command}}\n\n' | tac
}

SERVICE_PREFIX=${SERVICE_PREFIX:-'nirvai_'}
ENV=${ENV:-development}

get_cunt_id() {
  cunt_id=$(docker ps -aqf "name=^${1}$")

  if test -z $cunt_id; then
    echo $(docker ps -aqf "name=^${SERVICE_PREFIX}${1}$")
  else
    echo $cunt_id
  fi
}

save_canonical_compose_config() {
  dk_ps

  echo -e "\nforcing .env.${ENV}.compose.[yaml, json] in current dir"
  docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
  docker compose convert >.env.${ENV}.compose.yaml
}
cunts_restart() {
  echo -e "restarting all containers"
  docker compose up -d --force-recreate --wait
  save_canonical_compose_config
}
cunt_restart() {
  cunt_id=$(get_cunt_id $1)
  rebuild_image=${2:-0}

  if test -z "$cunt_id"; then
    echo -e "couldnt find container with name $1 or ${SERVICE_PREFIX}${1}"
    exit 1
  fi

  dk_up_flags='-d --force-recreate --wait'

  if [ "$rebuild_image" == "1" ]; then
    echo 'also rebuilding container image'
    dk_up_flags="$dk_up_flags --build"
  fi

  docker compose up $dk_up_flags
  save_canonical_compose_config
}
cmd=${1:-'all'}
case $cmd in
all) cunts_restart ;;
*) cunt_restart "$@" ;;
esac
