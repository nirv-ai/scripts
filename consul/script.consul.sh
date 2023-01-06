#!/usr/bin/env bash

# inspired by https://github.com/hashicorp-education/learn-consul-get-started-vms/tree/main/scripts
## TODO: must match the interface set by the other scripts
## TODO: this file should *only* use the http api

set -euo pipefail

# INTERFACE
## locations
BASE_DIR=$(pwd)
REPO_DIR=$BASE_DIR/core
APPS_DIR=$REPO_DIR/apps

APP_PREFIX=nirvai
ENV=development
CONSUL_INSTANCE_DIR_NAME=core-consul
CONSUL_INSTANCE_SRC_DIR=$APPS_DIR/$APP_PREFIX-$CONSUL_INSTANCE_DIR_NAME/src
CONSUL_DATA_DIR="${CONSUL_INSTANCE_SRC_DIR}/data"
CONSUL_INSTANCE_CONFIG_DIR="${CONSUL_INSTANCE_SRC_DIR}/config"
JAIL="${BASE_DIR}/secrets/${ENV}"

## vars
CONSUL_SERVICE_NAME=core_consul
DATACENTER="us-east"
DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
DOMAIN="mesh.nirv.ai"

# CONSUL_CONFIG_TARGET="${CONSUL_INSTANCE_CONFIG_DIR}/${CONSUL_CONFIG_TARGET:-''}"

######################## ERROR HANDLING
echo_debug() {
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.CONSUL.SH\n------------'
    echo -e "$@"
    echo -e "------------\n\n"
  fi
}
invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/consul/README.md"

  echo_debug $INVALID_REQUEST_MSG
}
throw_if_file_doesnt_exist() {
  if test ! -f "$1"; then
    echo -e "file doesnt exist: $1"
    exit 1
  fi
}
throw_if_dir_doesnt_exist() {
  if test ! -d "$1"; then
    echo -e "directory doesnt exist: $1"
    exit 1
  fi
}

######################## utils
validate() {
  file_or_dir=${1:-'file or directory required for validation'}

  consule validate $1
}

cmd=${1:-''}

case $cmd in
create)
  what=${2:?''}

  case $what in
  gossipkey)
    throw_if_dir_doesnt_exist $JAIL
    mkdir -p $JAIL/consul/tls
    consul keygen >$JAIL/consul/tls/gossipkey
    ;;
  tls)
    throw_if_dir_doesnt_exist $JAIL
    mkdir -p $JAIL/consul/tls
    cd $JAIL/consul/tls
    consul tls ca create -domain ${DOMAIN}
    consul tls cert create -server -domain ${DOMAIN} -dc=${DATACENTER}
    ;;
  *) invalid_request ;;
  esac
  ;;
*) $invalid_request ;;
esac
