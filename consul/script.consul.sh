#!/usr/bin/env bash

set -euo pipefail

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/consul/README.md'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"
SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-1}"

# grouped by increasing order of dependency
APP_PREFIX='nirvai'
CONFIGS_DIR_NAME=configs
CONSUL_INSTANCE_DIR_NAME='core-consul'
CONSUL_SERVICE_NAME=core-consul
DATACENTER=us-east
JAIL="${SCRIPTS_DIR_PARENT}/secrets"
MESH_HOSTNAME=mesh.nirv.ai
REPO_DIR="${SCRIPTS_DIR_PARENT}/core"
GOSSIP_KEY_NAME='config.consul.gossip.hcl'

APPS_DIR="${REPO_DIR}/apps"

JAIL_TLS="${JAIL}/${MESH_HOSTNAME}/tls"
JAIL_TOKENS="${JAIL}/consul/tokens"
JAIL_KEYS="${JAIL}/consul/keys"

CONSUL_INSTANCE_SRC_DIR="${APPS_DIR}/${APP_PREFIX}-${CONSUL_INSTANCE_DIR_NAME}/src"
JAIL_GOSSIP_KEY="${JAIL_KEYS}/${GOSSIP_KEY_NAME}"

CONSUL_INSTANCE_CONFIG_DIR="${CONSUL_INSTANCE_SRC_DIR}/config"
CONSUL_INSTANCE_POLICY_DIR="${CONSUL_INSTANCE_SRC_DIR}/policy"

# CONSUL_CONFIG_TARGET="${CONSUL_INSTANCE_CONFIG_DIR}/${CONSUL_CONFIG_TARGET:-''}"

declare -A EFFECTIVE_INTERFACE=(
  [CONSUL_INSTANCE_CONFIG_DIR]=$CONSUL_INSTANCE_CONFIG_DIR
  [CONSUL_INSTANCE_POLICY_DIR]=$CONSUL_INSTANCE_POLICY_DIR
  [DATACENTER]=$DATACENTER
  [JAIL_GOSSIP_KEY]=$JAIL_GOSSIP_KEY
  [JAIL_TLS]=$JAIL_TLS
  [JAIL_TOKENS]=$JAIL_TOKENS

  # [CLIENT_NAME]=$CLIENT_NAME
  # [JAIL_TLS]=$JAIL_TLS
  # [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  # [SCRIPTS_DIR]=$SCRIPTS_DIR
  # [SERVER_NAME]=$SERVER_NAME
)

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## CREDIT CHECK
echo_debug_interface

throw_missing_program consul 400 '@see https://developer.hashicorp.com/consul/downloads'
throw_missing_program jq 400 'sudo apt install jq'

throw_missing_dir $JAIL 400 "mkdir -p $JAIL"
throw_missing_dir $JAIL_TLS 400 '@see https://github.com/nirv-ai/docs/tree/main/cfssl'

######################## FNS
## reusable
validate_consul() {
  file_or_dir=${1:-'file or directory required for validation'}

  consule validate $1
}

## actions
create_gossip_key() {
  echo_debug 'creating gossip key'
  mkdir -p $JAIL_KEYS
  echo "encrypt = \"$(consul keygen)\"" >$JAIL_GOSSIP_KEY
}

## todo
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
    throw_missing_file $consul_admin_token 400 'cant find admin token token'
    echo $(cat $consul_admin_token | jq -r ".SecretID")
    ;;
  dns-token)
    server_dns_Token="${JAIL}/tokens/dns-acl.token.json"
    throw_missing_file $server_dns_Token 400 'couldnt find dns token'
    echo $(cat $server_dns_Token | jq -r ".SecretID")
    ;;
  server-acl-token)
    server_node_token="${JAIL}/tokens/server-acl.token.json"
    throw_missing_file $server_node_token 400 'cant find server token'
    echo $(cat $server_node_token | jq -r ".SecretID")
    ;;
  service-acl-token)
    svc_name=${3:?'svc_name required'}
    server_node_token="${JAIL}/tokens/${svc_name}-acl.token.json"
    throw_missing_file $server_node_token 'cant find service token'
    echo $(cat $server_node_token | jq -r ".SecretID")
    ;;
  *) invalid_request ;;
  esac
  ;;
create)
  what=${2:-''}

  case $what in
  gossipkey) create_gossip_key ;;
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
