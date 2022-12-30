#!/usr/bin/env sh

set -eu

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}
PROXY_WORK_DIR=${PROXY_WORK_DIR:-/usr/local/etc/haproxy}
HAPROXY_CONFIG_DIR=${HAPROXY_CONFIG_DIR:-./configs}
cmdhelp='invalid cmd: @see https://github.com/nirv-ai/docs/tree/main/scripts'

conf_validate() {
  echo $(docker exec --workdir $PROXY_WORK_DIR -it "${SERVICE_PREFIX}_${1}" haproxy -c -f "$HAPROXY_CONFIG_DIR")
}

conf_info() {
  docker exec --workdir $PROXY_WORK_DIR -it "${SERVICE_PREFIX}_${1}" haproxy -vv
}

conf_reload() {
  is_valid=$(conf_validate "$1")

  case $is_valid in
  "Configuration file is valid"*) docker kill -s HUP "${SERVICE_PREFIX}_${1}" ;;
  *) echo "\nnot reloading:\n$is_valid\n" ;;
  esac
}

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
