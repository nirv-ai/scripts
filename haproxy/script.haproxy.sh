#!/usr/bin/env sh

set -eu

PREFIX=${PREFIX:-nirvai_}

cmdhelp='invalid cmd: @see https://github.com/nirv-ai/docs/tree/main/scripts'

case $1 in
conf)
  case $2 in
  validate)
    docker exec --workdir /usr/local/etc/haproxy -it nirvai_core_proxy haproxy -c -f haproxy.cfg
    ;;
  reload)
    echo -e not setup
    # docker kill -s HUP my-running-haproxy
    ;;
  *) echo -e $cmdhelp ;;
  esac
  ;;
*) echo -e $cmdhelp ;;
esac
