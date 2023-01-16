#!/usr/bin/env bash

kill_service_on_port() {
  if [ "$#" -eq 0 ]; then
    echo -e 'syntax: kill_service_on_port 8080'
  else
    fuser -k $1/tcp
  fi
}

kill_service_by_name() {
  if [ "$#" -eq 0 ]; then
    echo -e 'syntax: kill_service_by_name poop'
  else
    # sudo kill -9 $(pidof $1)
    sudo killall $1 # handles it more gracefully
  fi
}

get_service_by_name() {
  if [ "$#" -eq 0 ]; then
    echo -e 'syntax: get_service_by_name poop'
  else
    ps -aux | grep $1
  fi
}
