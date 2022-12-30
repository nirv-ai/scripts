#!/usr/bin/env sh

set -eu

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}

if [ "$#" -eq 0 ]; then
  echo "please provide a docker compose service name"
else
  echo "trying to exec with bash"
  if ! docker exec -it "${SERVICE_PREFIX}_${1}" bash; then
    echo -e "trying to exec with sh"
    docker exec -it "${SERVICE_PREFIX}_${1}" sh
  fi
fi
