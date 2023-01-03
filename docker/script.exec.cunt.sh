#!/usr/bin/env sh

set -eu

NAME_PREFIX=${CUNT_NAME_PREFIX:-'nirvai_'}

get_cunt_name() {
  container_id=$(docker ps -aqf "name=^${1}$")

  if test ${#container_id} -gt 6; then
    echo $1
  else
    container_name_with_prefix="${NAME_PREFIX}${1}"
    container_id=$(docker ps -aqf "name=^${container_name_with_prefix}$")
    if test ${#container_id} -gt 6; then
      echo $container_name_with_prefix
    fi
  fi

  echo ""
}

exec_into_container() {
  cunt_name=$(get_cunt_name $1)

  if test -z "$cunt_name"; then
    echo "\ncouldnt find container with name $1 or ${NAME_PREFIX}${1}"
    exit 1
  fi

  echo "trying to exec with bash: $cunt_name\n"
  if ! docker exec -it "$cunt_name" bash; then
    echo
    echo "trying to exec with sh: $cunt_name\n"
    docker exec -it "$cunt_name" sh
  fi
}

cunt_name=${1:?'container name is required'}
case $cunt_name in
*) exec_into_container ${cunt_name} ;;
esac
