#!/usr/bin/env bash

################
## inspired by https://github.com/hashicorp-education/learn-consul-get-started-vms/tree/main/scripts
## TODO: must match the interface set by the other scripts
## TODO: this file can use either the cli/http api
## default files are owned by: systemd-network
### ^ every node requires the consul binary anyway, unlike vault
################ general flow
### create rootca & server certs
# create tokens rootca, server client & cli certs using script.ssl.sh
# create gossipkey using this script
# start core_consul
# validate cli not allowed: consul info
# should receive error: Error querying agent: Unexpected response code: 403 (Permission denied: token with AccessorID '00000000-0000-0000-0000-000000000002' lacks permission 'agent:read' on "consul")
# create admin token using this script
# source .env (see configs)
# valid cli can talk to consul: consul info
# should not receive any errors
# log in through the UI using the admin token: script.consul.sh get admin-token
# should have access to almost everything
### create policy files and push to consul server
# see policy dir
# dns policy: consul acl policy create -name 'acl-policy-dns' -description 'Policy for DNS endpoints' -rules @./acl-policy-dns.hcl
# server policy: consul acl policy create -name 'acl-policy-server-node' -description 'Policy for Server nodes' -rules @./acl-policy-server-node.hcl
# dns token: consul acl token create -description 'DNS - Default token' -policy-name acl-policy-dns --format json > ./dns-acl.token.json
# server token: consul acl token create -description "server agent token" -policy-name acl-policy-server-node  --format json > ./server-acl.token.json
# assign dns token to server: consul acl set-agent-token default ${DNS_TOKEN}
# assign server token to server: consul acl set-agent-token agent ${SERVER_TOKEN}
### update docker images to include binary (see proxy for ubuntu, vault for alpine)
### discovery: add configs for to each client machine
# @see https://developer.hashicorp.com/consul/tutorials/get-started-vms/virtual-machine-gs-service-discovery
# create a base discovery/client/config/* that can be used as defaults for each specific client service
# copy base client configs/* into each discovery/service-name/config/* dir

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
CONSUL_POLICY_DIR="${CONSUL_INSTANCE_SRC_DIR}/policy"
JAIL="${BASE_DIR}/secrets/mesh.nirv.ai/${ENV}"

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
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/README.md"

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

# consul kv put consul/configuration/db_port 5432
# consul kv get consul/configuration/db_port
# dig @127.0.0.1 -p 8600 consul.service.consul
# consul catalog services -tags
# consul reload
# consul services register svc-db.hcl

# consul poop poop -h has wonderful examples, thank me later
cmd=${1:-''}

case $cmd in
set)
  what=${2:?''}
  case $what in
  agent-tokens)
    if test -z ${CONSUL_DNS_TOKEN:-''}; then
      echo 'CONSUL_DNS_TOKEN not found in env`'
      exit 1
    fi

    if test -z ${CONSUL_SERVER_NODE_TOKEN:-''}; then
      echo 'CONSUL_SERVER_NODE_TOKEN not found in env`'
      exit 1
    fi

    echo -e "TODO: setting static dns & server node tokens"

    consul acl set-agent-token default ${CONSUL_DNS_TOKEN}
    consul acl set-agent-token agent ${CONSUL_SERVER_NODE_TOKEN}
    ;;
  esac
  ;;
get)
  what=${2:?''}
  case $what in
  server-members)
    consul members
    ;;
  admin-token)
    consul_admin_token="${JAIL}/tokens/admin-consul.token.json"
    throw_if_file_doesnt_exist $consul_admin_token
    echo $(cat $consul_admin_token | jq -r ".SecretID")
    ;;
  dns-token)
    server_dns_Token="${JAIL}/tokens/dns-acl.token.json"
    throw_if_file_doesnt_exist $server_dns_Token
    echo $(cat $server_dns_Token | jq -r ".SecretID")
    ;;
  server-node-token)
    server_node_token="${JAIL}/tokens/server-acl.token.json"
    throw_if_file_doesnt_exist $server_node_token
    echo $(cat $server_node_token | jq -r ".SecretID")
    ;;
  service-acl-token)
    svc_name=${3:?'svc_name required'}
    server_node_token="${JAIL}/tokens/${svc_name}-acl.token.json"
    throw_if_file_doesnt_exist $server_node_token
    echo $(cat $server_node_token | jq -r ".SecretID")
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
    mkdir -p $JAIL/tls
    consul keygen >$JAIL/tls/gossipkey
    ;;
  consul-admin-token)
    mkdir -p $JAIL/tokens
    consul acl bootstrap --format json >$JAIL/tokens/admin-consul.token.json
    ;;
  service-token)
    svc_name=${3:?'service name is required'}
    echo 'TODO: creating static acl tokens'

    mkdir -p $JAIL/tokens

    consul acl token create \
      -node-identity "${svc_name}:us-east" \
      -service-identity="${svc_name}" \
      --format json >${JAIL}/tokens/${svc_name}-acl.token.json 2>/dev/null
    ;;
  acl-token)
    echo 'TODO: creating static acl tokens'

    consul acl token create \
      -policy-name acl-policy-dns \
      --format json >$JAIL/tokens/dns-acl.token.json

    consul acl token create \
      -policy-name acl-policy-server-node \
      --format json >$JAIL/tokens/server-acl.token.json
    ;;
  policy)
    echo -e 'TODO: creating static policies\n\n'

    consul acl policy create \
      -name 'acl-policy-dns' \
      -rules @$CONSUL_POLICY_DIR/acl-policy-dns.hcl 2>/dev/null

    consul acl policy create \
      -name 'acl-policy-server-node' \
      -rules @$CONSUL_POLICY_DIR/acl-policy-server-node.hcl 2>/dev/null
    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
