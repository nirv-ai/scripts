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
DATACENTER=us-east
DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
MESH_HOSTNAME=mesh.nirv.ai

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
get)
  what=${2:?''}
  case $what in
  admin-token)
    consul_admin_token="${JAIL}/consul/tokens/admin-consul.token.json"
    throw_if_file_doesnt_exist $consul_admin_token
    echo $(cat $consul_admin_token | jq -r ".SecretID")
    ;;
  *) invalid_request ;;
  esac
  ;;
create)
  what=${2:?''}

  case $what in
  consul_group)
    echo_debug "sudo required: adding $USER to group consul"

    sudo groupadd consul 2>/dev/null
    sudo usermod -aG consul $USER
    # sudo chown -R $USER:consul /etc/ssl/certs/development/consul
    ;;
  gossipkey)
    throw_if_dir_doesnt_exist $JAIL
    mkdir -p $JAIL/consul/tls
    consul keygen >$JAIL/consul/tls/gossipkey
    ;;
  consul-admin-token)
    mkdir -p $JAIL/consul/tokens
    consul acl bootstrap --format json >$JAIL/consul/tokens/admin-consul.token.json
    ;;
  tls)
    throw_if_dir_doesnt_exist $JAIL

    mkdir -p $JAIL/consul/tls
    rm -rf $JAIL/consul/tls/*.pem
    sudo rm -rf $CONSUL_DATA_DIR/*
    cd $JAIL/consul/tls
    name=consul-ca

    # generate priv key and cert for consul ca
    cfssl print-defaults csr |
      cfssl gencert -initca - |
      cfssljson -bare $name

    # generate privkey and cert for consul server
    echo '{}' |
      cfssl gencert -ca=$name.pem -ca-key=$name-key.pem -config=cfssl.json \
        -hostname="localhost,127.0.0.1,server.${DATACENTER}.${MESH_HOSTNAME},${MESH_HOSTNAME}" - |
      cfssljson -bare server

    # generate certs for the client server
    echo '{}' |
      cfssl gencert -ca=$name.pem -ca-key=$name-key.pem -config=cfssl.json \
        -hostname="localhost,127.0.0.1,${MESH_HOSTNAME}" - |
      cfssljson -bare client

    # generate certs for cli communication
    echo '{}' |
      cfssl gencert -ca=$name.pem -ca-key=$name-key.pem -profile=client - |
      cfssljson -bare cli

    for file in $JAIL/consul/tls/*.pem; do
      echo -e "\n\nvalidating file: $file\n\n"
      openssl x509 -in $file -text -alias 2>/dev/null || true
    done
    chmod 0644 $JAIL/consul/tls/*.pem
    chmod 0640 $JAIL/consul/tls/*key.pem
    # ln -s `pwd`/development /etc/ssl/certs/development
    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
