#!/usr/bin/env bash

# inspired by https://github.com/hashicorp-education/learn-consul-get-started-vms/tree/main/scripts
## TODO: must match the interface set by the other scripts

set -euo pipefail

# INTERFACE
## locations
BASE_DIR=$(pwd)
REPO_DIR=$BASE_DIR/core
APPS_DIR=$REPO_DIR/apps
APP_PREFIX=nirvai
CONSUL_INSTANCE_DIR_NAME=core-consul
CONSUL_INSTANCE_SRC_DIR=$APPS_DIR/$APP_PREFIX-$CONSUL_INSTANCE_DIR_NAME/src
CONSUL_DATA_DIR="${CONSUL_INSTANCE_SRC_DIR}/data"
CONSUL_INSTANCE_CONFIG_DIR="${CONSUL_INSTANCE_SRC_DIR}/config"

## vars
CONSUL_SERVICE_NAME=core_consul
DATACENTER="us-east"
DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
DOMAIN="mesh.nirv.ai"

# CONSUL_CONFIG_TARGET="${CONSUL_INSTANCE_CONFIG_DIR}/${CONSUL_CONFIG_TARGET:-''}"

######################## DEBUG ECHO
echo_debug() {
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.CONSUL.SH\n------------'
    echo -e "$@"
    echo -e "------------\n\n"
  fi
}

cmd=${1:?'available cmds: create'}
cmdhelp='@see https://github.com/nirv-ai/docs/tree/main/consul'

case $cmd in
create)
  what=${2:?'syntax: create config'}

  case $what in
  config)
    type=${3:?'syntax: create config server|client|mesh'}
    case $type in
    server) echo_debug 'creating server config' ;;
    client) echo_debug 'creating client config' ;;
    mesh) echo_debug 'creating client mesh config' ;;
    esac
    ;;
  *) echo $cmdhelp ;;
  esac
  ;;
*) echo $cmdhelp ;;
esac
