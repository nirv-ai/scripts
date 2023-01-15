#!/usr/bin/env bash

set -eu

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/tree/main/scripts'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## FNS

exec_into_container() {
  cunt_id=$(get_cunt_id $1)

  if test -z "$cunt_id"; then
    echo_err "\ncouldnt find container with name $1 or ${CUNT_PREFIX}${1}"
    exit 1
  fi

  local exec_args='-it'
  local as_user=${2:-''}

  if ! test -z $as_user; then
    exec_args="$exec_args -u $as_user"
  fi

  local args="\n$1: $cunt_id\nargs: $exec_args"
  echo_debug "trying to exec with bash\n$args"
  if ! docker exec $exec_args "$cunt_id" bash; then
    echo
    echo_debug "trying to exec with sh\n$args"
    docker exec $exec_args "$cunt_id" sh
  fi
}

cunt_name=${1:?'container name is required'}
case $cunt_name in
*) exec_into_container ${cunt_name} ${2:-''} ;;
esac
