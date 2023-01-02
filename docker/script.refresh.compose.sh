#!/usr/bin/env bash

set -e

###########################
# refreshes a container
# for something more destructive, use reset script
###########################

# @see bookOfNoah
dk_ps() {
  docker ps --no-trunc -a --format 'table {{.Names}}\n\t{{.Image}}\n\t{{.Status}}\n\t{{.Command}}\n\n' | tac
}

SERVICE_PREFIX=${SERVICE_PREFIX:-'nirvai_'}
ENV=${NODE_ENV:-development}

echo 'inside'
echo
echo

if [ "$#" -eq 0 ]; then
  echo "restarting all containers"
  docker compose down
  docker compose up --force-recreate --build -d
elif [ "$1" == "rebuild" ]; then
  echo "rebuilding and restarting containers"
  docker compose down
  docker compose build --no-cache
  docker compose up --force-recreate -d
else
  echo "restarting $1"
  docker container stop "${SERVICE_PREFIX}${1}" || true

  if [ "$2" == "1" ]; then
    echo 'also removing container and rebuilding image'
    docker container rm "${SERVICE_PREFIX}${1}" || true
    docker compose build --no-cache --progress=plain $1
  fi
  docker compose up -d $1 --remove-orphans
fi

dk_ps

echo -e "forcing .env.${ENV}.compose.[yaml, json] in current dir"
docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
docker compose convert >.env.${ENV}.compose.yaml
# docker compose config
