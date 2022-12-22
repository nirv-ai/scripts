#!/usr/bin/env bash

set -eu

NAME_PREFIX=${NAME_PREFIX:-nirvai_core_}

if [ "$#" -eq 0 ]; then
  echo "please provide a docker compose service name"
else
  echo "trying to exec with bash"
  if ! docker exec -it $NAME_PREFIX${1} bash; then
    echo -e "trying to exec with sh"
    docker exec -it $NAME_PREFIX${1} sh
  fi
fi
