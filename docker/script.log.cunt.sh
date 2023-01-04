#!/usr/bin/env bash

set -euo pipefail

NAME_PREFIX=${CUNT_NAME_PREFIX:-'nirvai_'}

get_cunt_id() {
  container_id=$(docker ps -aqf "name=^${1}$")

  if test ${#container_id} -gt 6; then
    echo $container_id
  else
    container_name_with_prefix="${NAME_PREFIX}${1}"
    container_id=$(docker ps -aqf "name=^${container_name_with_prefix}$")
    if test ${#container_id} -gt 6; then
      echo $container_id
    fi
  fi

  echo ""
}

cmd=${1:-''}
case $1 in
disk)
  name=${2:-""}
  if [[ -z $name ]]; then
    echo -e "syntax: logs appname"
    exit 1
  fi

  cunt_id=$(get_cunt_id $name)

  if test -z "$cunt_id"; then
    echo -e "\ncouldnt find container with name $2 or ${NAME_PREFIX}${2}"
    exit 1
  fi

  log_file_on_disk="/var/lib/docker/containers/$cunt_id/$cunt_id-json.log"

  if test ! -f "$log_file_on_disk"; then
    echo "no log files exist at $log_file_on_disk"
    exit 0
  fi

  echo -e "displaying log file: $log_file_on_disk"
  sudo cat $log_file_on_disk | jq

  ;;
*) echo -e "available cmds: disk CONTAINER_NAME" ;;
esac
