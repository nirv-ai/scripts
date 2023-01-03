#!/usr/bin/env sh

set -euo pipefail

SERVICE_PREFIX=${SERVICE_PREFIX:-'nirvai_'}

exec_into_container() {
  cunt_name=${1:?'container name required for docker exec'}

  echo
  echo "trying to exec with bash: $cunt_name\n"
  if ! docker exec -it "$cunt_name" bash; then
    echo
    echo "trying to exec with sh: $cunt_name\n"
    docker exec -it "$cunt_name" sh
  fi
}

cunt_name=${1:?'syntax cunt containerName | serviceName'}
case $cunt_name in
cunt) exec_into_container ${2:?'syntax: cunt containerName'} ;;
*) exec_into_container ${SERVICE_PREFIX}${cunt_name} ;;
esac
