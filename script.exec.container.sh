#!/usr/bin/env bash

set -e

if [ "$#" -eq 0 ]; then
  echo "please provide a docker compose service name"
else
  echo "trying to exec with bash"
  if ! docker exec -it nirvai__core_${1} bash; then
    echo -e "trying to exec with sh"
    docker exec -it nirvai_core_${1} sh
  fi
fi
