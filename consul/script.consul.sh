#!/usr/bin/env bash

################
## inspired by https://github.com/hashicorp-education/learn-consul-get-started-vms/tree/main/scripts
## TODO: must match the interface set by the other scripts
## TODO: this file can use either the cli/http api
### ^ every node requires the consul binary anyway, unlike vault
## default files are owned by: systemd-network
################ general flow:
# TODO: move this into docs and fkn automate this shiz like script.vault.sh
# ensure consul:consul is setup on host
# ensure all application files & secrets on host are owned by consul:consul
# in every image that runs consul (client|server)
# force img consul:consul to match host consul:consul
### create rootca & server certs
# create tokens rootca, server client & cli certs using script.ssl.sh
# `create gossipkey`
# script.reset core_consul
# `get info` >>> Error querying agent: Unexpected response code: 403 (Permission denied: token with AccessorID '00000000-0000-0000-0000-000000000002' lacks permission 'agent:read' on "consul")
# `create consul-admin-token`
# `. .env.cli`
# `get info` >>> should not receive any errors
# `get consul-admin-token` >>> validate UI login
# should have access to almost everything
### create policy files and tokens and push to consul server
# see policy dir
# `create policy`
# `list policies`
# `create acl-token` >>> put known services here for now
# `create server-token svc-name` # for testing new services never use _ in service names, must match svc configs
# `. .env.consul.server`
# `list tokens`
# `set agent-tokens` >>> from [WARN] agent: ...blocked by acls... --> to agent: synced node info
### update docker images to include binary (see proxy for ubuntu, vault for alpine)
### DISCOVERY: add configs for to each client machine
# @see https://developer.hashicorp.com/consul/tutorials/get-started-vms/virtual-machine-gs-service-discovery
# create a base discovery/client/config/* that can be used as defaults for each specific client service
# create discovery/service-name/config/* configs
# copy discovery/{client,service-name}/configs/* into each app/service-name/consul/src/config
# validate each config has the data it needs
# ^ `get service-acl-token core-proxy`
# ^ `get team` >>> need the server ip for retry_join, for some reason setting hostname doesnt work
# ^ reuse gossipkey, should be in jail/tls/gossipkey
# ^^ TODO: gossipkey should be a symlink to /run/secrets
# ^ (TODO: automate this)
# sudo chown -R consul:consul app/svc-name/src/consul
# ^ required due to secrets gid/uid bug, check CONSUL_{GID,UID} vars in compose .env
# sudo rm -rf app/svc-name/src/consul/data/* if starting from scratch
# script.reset|refresh compose_service_name(s) to boot consul clients
### MESH: this is a migration from discovery to mesh

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
# consul services register svc-db.hcl

# consul cmd cmd cmd --help has wonderful examples, thank me later
cmd=${1:-''}

case $cmd in
reload) consul reload ;;
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
  *) invalid_request ;;
  esac
  ;;
list)
  what=${2:-''}

  case $what in
  policies) consul acl policy list -format=json ;;
  tokens) consul acl token list -format=json ;;
  *) invalid_request ;;
  esac
  ;;
get)
  what=${2:-''}

  case $what in
  info)
    consul info
    ;;
  team)
    consul members
    ;;
  consul-admin-token)
    consul_admin_token="${JAIL}/tokens/admin-consul.token.json"
    throw_if_file_doesnt_exist $consul_admin_token
    echo $(cat $consul_admin_token | jq -r ".SecretID")
    ;;
  dns-token)
    server_dns_Token="${JAIL}/tokens/dns-acl.token.json"
    throw_if_file_doesnt_exist $server_dns_Token
    echo $(cat $server_dns_Token | jq -r ".SecretID")
    ;;
  server-acl-token)
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
  what=${2:-''}

  case $what in
  gossipkey)
    throw_if_dir_doesnt_exist $JAIL
    mkdir -p $JAIL/tls
    consul keygen >$JAIL/tls/gossipkey
    ;;
  consul-admin-token)
    mkdir -p $JAIL/tokens
    consul acl bootstrap --format json >$JAIL/tokens/admin-consul.token.json
    ;;
  policy)
    echo -e 'TODO: creating static policies\n\n'

    consul acl policy create \
      -name 'acl-policy-dns' \
      -rules @$CONSUL_POLICY_DIR/acl-policy-dns.hcl || true

    consul acl policy create \
      -name 'acl-policy-server-node' \
      -rules @$CONSUL_POLICY_DIR/acl-policy-server-node.hcl || true

    consul acl policy create \
      -name 'acl-policy-core-proxy' \
      -rules @$CONSUL_POLICY_DIR/acl-policy-core-proxy.hcl || true

    consul acl policy create \
      -name 'acl-policy-core-vault' \
      -rules @$CONSUL_POLICY_DIR/acl-policy-core-vault.hcl || true
    ;;
  service-token)
    # reuse existing things if resetting data|configs
    # -secret=<string>
    # -role-name=<value>
    svc_name=${3:?'service name is required'}
    policy_name=${4:?'policy name is required'}
    echo 'TODO: creating static acl tokens'

    mkdir -p $JAIL/tokens

    consul acl token create \
      -node-identity="${svc_name}:us-east" \
      -service-identity="${svc_name}" \
      -policy-name="$policy_name" \
      -description="acl token for ${svc_name}" \
      --format json >${JAIL}/tokens/${svc_name}-acl.token.json 2>/dev/null
    ;;
  acl-token)
    # reuse existing things if resetting data|configs
    # -secret=<string>
    # -role-name=<value>
    echo 'TODO: creating static acl tokens for known services'

    consul acl token create \
      -node-identity="core-proxy:us-east" \
      -service-identity="core-proxy" \
      -policy-name="acl-policy-core-proxy" \
      -description="acl token for core-proxy" \
      --format json >${JAIL}/tokens/core-proxy-acl.token.json 2>/dev/null

    consul acl token create \
      -node-identity="core-vault:us-east" \
      -service-identity="core-vault" \
      -policy-name="acl-policy-core-vault" \
      -description="acl token for core-vault" \
      --format json >${JAIL}/tokens/core-vault-acl.token.json 2>/dev/null

    consul acl token create \
      -policy-name='acl-policy-dns' \
      -description='core server dns token' \
      --format json >$JAIL/tokens/dns-acl.token.json

    consul acl token create \
      -policy-name='acl-policy-server-node' \
      -description='core server acl token' \
      --format json >$JAIL/tokens/server-acl.token.json
    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
