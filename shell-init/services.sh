#!/usr/bin/env bash

get_services() {
  getent services
}
export -f get_services

wait_for_service_on_port() {
  if test $# -eq 2; then
    while true; do
      if test $(netstat -tulanp | grep "$2" | grep LISTEN); then
        echo "$1 is up on port $2"
        break
      else
        echo "$1 is not up on port $2"
        sleep 1
      fi
    done
  else
    echo "\$1 === service name"
    echo "\$2 === port"
  fi
}
export -f wait_for_service_on_port

kill_service_on_port() {
  if [ "$#" -eq 0 ]; then
    echo -e 'syntax: kill_service_on_port 8080'
  else
    fuser -k $1/tcp
  fi
}
export -f kill_service_on_port

kill_service_by_name() {
  if [ "$#" -eq 0 ]; then
    echo -e 'syntax: kill_service_by_name poop'
  else
    # sudo kill -9 $(pidof $1)
    sudo killall $1 # handles it more gracefully
  fi
}
export -f kill_service_by_name

get_service_by_name() {
  if [ "$#" -eq 0 ]; then
    echo -e 'syntax: get_service_by_name poop'
  else
    ps -aux | grep $1
  fi
}
export -f get_service_by_name
