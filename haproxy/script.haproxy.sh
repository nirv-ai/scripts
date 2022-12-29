#!/usr/bin/env sh

set -eu

PREFIX=${PREFIX:-nirvai_}

cmdhelp='invalid cmd: @see https://github.com/nirv-ai/docs/tree/main/scripts'

cmd=${1:?$cmdhelp}

case $cmd in
conf)
  action=${2:-''}
  case $action in
  validate)
    cunt_name=${3-?'syntax: conf validate SERVICE_NAME'}
    docker exec --workdir /usr/local/etc/haproxy -it ${PREFIX}${cunt_name} haproxy -c -f haproxy.cfg
    ;;
  reload)
    cunt_name=${3-?'syntax: conf reload SERVICE_NAME'}
    docker kill -s HUP ${PREFIX}${cunt_name}
    ;;
  *) echo -e $cmdhelp ;;
  esac
  ;;
*) echo -e $cmdhelp ;;
esac
