#!/usr/bin/env bash

set -e

###########################
# refreshes a container
# for something more destructive, use reset script
###########################

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}

if [ "$#" -eq 0 ]; then
  echo "restarting all containers"
  docker compose restart
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
