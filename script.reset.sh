#!/usr/bin/env bash

set -e

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}

create_volumes() {
  local POSTGRES_VOL=$SERVICE_PREFIX-core-postgres

  docker volume create $POSTGRES_VOL
}

build() {
  docker compose build --progress=plain
}

up() {
  docker compose up -d --remove-orphans
}

echo -e "running reset"

case $1 in
volumes)
  create_volumes
  docker volume ls
  ;;
core*)
  echo "resetting infrastructore for $1"
  if ! docker container kill $SERVICE_PREFIX-$1; then
    echo "container for service $1 already dead"
  else
    docker container rm $SERVICE_PREFIX-$1
  fi
  docker container prune -f
  echo "restarting server $1"
  docker compose build $1
  docker compose up -d $1 --remove-orphans
  ;;
*)
  echo 'resetting infrastructure'
  docker compose down
  dk_rm_all
  build
  up
  ;;
esac

dk_ps
