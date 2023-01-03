#!/usr/bin/env bash

###########################
# resets a container & image
# for something less destructive, use refresh script
###########################

set -euo pipefail

NAME_PREFIX=${CUNT_NAME_PREFIX:-'nirvai_'}
POSTGRES_HOSTNAME=${POSTGRES_HOSTNAME:-'web_postgres'}
POSTGRES_VOL_NAME="${NAME_PREFIX}${POSTGRES_HOSTNAME}"
ENV=${ENV:-development}

dk_ps() {
  docker ps --no-trunc -a --format 'table {{.Names}}\n\t{{.Image}}\n\t{{.Status}}\n\t{{.Command}}\n\n' | tac
}

get_cunt_id() {
  container_id=$(docker ps --no-trunc -aqf "name=^${1}$")

  if test ${#container_id} -gt 6; then
    echo $container_id
  else
    container_name_with_prefix="${NAME_PREFIX}${1}"
    container_id=$(docker ps --no-trunc -aqf "name=^${container_name_with_prefix}$")
    if test ${#container_id} -gt 6; then
      echo $container_id
    fi
  fi

  echo ""
}

create_volumes() {
  docker volume create $POSTGRES_VOL_NAME || true
}

build() {
  docker compose build --no-cache --progress=plain
}

up() {
  docker compose up -d --remove-orphans
}

echo -e "running reset"

docker compose config

case $1 in
volumes)
  create_volumes
  docker volume ls
  ;;
core*)
  echo "resetting infrastructore for $1"
  if ! docker container kill ${NAME_PREFIX}${1}; then
    echo "container for service $1 already dead"
  else
    docker container rm ${NAME_PREFIX}${1}
  fi
  docker container prune -f
  docker volume prune
  create_volumes
  echo "restarting server $1"
  docker compose build --no-cache $1
  docker compose up -d $1 --remove-orphans
  ;;
*)
  echo -e 'resetting infrastructure'
  docker compose down
  docker stop $(docker ps -a -q) || true
  docker rm $(docker ps -a -q) || true
  docker system prune -a || true
  docker volume prune || true
  create_volumes
  build
  up
  ;;
esac

dk_ps

echo -e "forcing .env.${ENV}.compose.[yaml, json] in current dir"
docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
docker compose convert >.env.${ENV}.compose.yaml
