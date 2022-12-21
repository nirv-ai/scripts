#!/usr/bin/env bash

set -e

###########################
# refreshes a container
# for something more destructive, use reset script
###########################

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}

docker compose config

if [ "$#" -eq 0 ]; then
  echo "restarting all containers"
  docker compose restart
elif [ "$1" == "restart" ]; then
  echo "restarting all running containers"
  docker compose restart
  dk_ps
else
  echo "restarting $1"
  docker container stop "$SERVICE_PREFIX-$1" || true

  if [ "$2" == "1" ]; then
    echo 'also removing container and rebuilding image'
    docker container rm "$SERVICE_PREFIX-$1" || true
    docker compose build --no-cache --progress=plain $1
  fi
  docker compose up -d $1 --remove-orphans
fi

docker compose convert $1

dk_ps
