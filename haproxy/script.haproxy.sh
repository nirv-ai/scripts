#!/usr/bin/env bash

set -eu

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/tree/main/scripts'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"
SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# grouped by increasing order of dependency
PROXY_WORK_DIR=${PROXY_WORK_DIR:-/usr/local/etc/haproxy}
HAPROXY_CONFIG_DIR=${HAPROXY_CONFIG_DIR:-./configs}

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## FNS
conf_validate() {
  cunt_id=$(get_cunt_id $1)
  if test -z $cunt_id; then
    echo_err "matching $1 container not found: exiting"
    exit 1
  fi

  echo $(docker exec --workdir $PROXY_WORK_DIR -it "$cunt_id" haproxy -c -f "$HAPROXY_CONFIG_DIR")
}

conf_info() {
  cunt_id=$(get_cunt_id $1)
  if test -z $cunt_id; then
    echo_err "matching $1 container not found: exiting"
    exit 1
  fi

  docker exec --workdir $PROXY_WORK_DIR -it "$cunt_id" haproxy -vv
}

conf_reload() {
  # @see https://github.com/haproxytech/haproxy/blob/master/blog/integration_with_consul/haproxy_reload.sh
  echo "TODO: this just kills the container, instead use script.refresh.compose.sh $1"

  exit 0

  is_valid=$(conf_validate "$1")

  cunt_id=$(get_cunt_id $1)
  if test -z $cunt_id; then
    echo_err "matching $1 container not found: exiting"
    exit 1
  fi

  case $is_valid in
  "Configuration file is valid"*) docker kill -s SIGUSR2 "$cunt_id" ;;
  *) echo_err "\nnot reloading:\n$is_valid\n" ;;
  esac
}

cmdhelp="invalid cmd: @see $DOCS_URI"

cmd=${1:?$cmdhelp}
case $cmd in
conf)
  action=${2:-''}
  case $action in
  validate)
    cunt_name=${3:?'syntax: conf validate SERVICE_NAME'}
    conf_validate $cunt_name
    ;;
  info)
    cunt_name=${3:?'syntax: conf info SERVICE_NAME'}
    conf_info $cunt_name
    ;;
  reload)
    cunt_name=${3:?'syntax: conf reload SERVICE_NAME'}
    conf_reload $cunt_name
    ;;
  *) echo -e $cmdhelp ;;
  esac
  ;;
*) echo -e $cmdhelp ;;
esac
