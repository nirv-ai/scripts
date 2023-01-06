#!/usr/bin/env sh

set -eu

# TODO: update docs about using the project + service name instead of hardcoding a container name
NAME_PREFIX=${CUNT_NAME_PREFIX:-'nirvai_core-'}

# gets the first container with the matching name
get_cunt_name() {
  # perhaps they passed the containers full name
  local container_id=$(docker ps -aqf "name=^${1}$")

  if test ${#container_id} -gt 6; then
    echo $container_id
  else # try with the prefix
    container_name_with_prefix="${NAME_PREFIX}${1}"
    container_id=$(docker ps -aqf "name=^${container_name_with_prefix}" | head -n 1)
    if test ${#container_id} -gt 6; then
      echo $container_id
    fi
  fi

  echo ""
}

exec_into_container() {
  cunt_id=$(get_cunt_name $1)

  if test -z "$cunt_id"; then
    echo "\ncouldnt find container with name $1 or ${NAME_PREFIX}${1}"
    exit 1
  fi

  echo "trying to exec with bash: $1: $cunt_id\n"
  if ! docker exec -it "$cunt_id" bash; then
    echo
    echo "trying to exec with sh: $1: $cunt_id\n"
    docker exec -it "$cunt_id" sh
  fi
}

cunt_name=${1:?'container name is required'}
case $cunt_name in
*) exec_into_container ${cunt_name} ;;
esac
