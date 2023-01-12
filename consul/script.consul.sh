#!/usr/bin/env bash

set -euo pipefail

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/consul/README.md'
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# grouped by increasing order of dependency
APP_PREFIX='nirvai'
CONFIGS_DIR_NAME=configs
CONSUL_INSTANCE_DIR_NAME='core-consul'
CONSUL_SERVICE_NAME=core-consul
DATACENTER=us-east
GOSSIP_KEY_NAME='config.consul.gossip.hcl'
JAIL="${SCRIPTS_DIR_PARENT}/secrets"
MESH_HOSTNAME=mesh.nirv.ai
REPO_DIR="${SCRIPTS_DIR_PARENT}/core"
ROOT_TOKEN_NAME=token.root.json

APPS_DIR="${REPO_DIR}/apps"
CONFIG_DIR_POLICY="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/policy"
JAIL_DIR_KEYS="${JAIL}/consul/keys"
JAIL_DIR_TLS="${JAIL}/${MESH_HOSTNAME}/tls"
JAIL_DIR_TOKENS="${JAIL}/consul/tokens"

CONSUL_INSTANCE_SRC_DIR="${APPS_DIR}/${APP_PREFIX}-${CONSUL_INSTANCE_DIR_NAME}/src"
JAIL_KEY_GOSSIP="${JAIL_DIR_KEYS}/${GOSSIP_KEY_NAME}"
JAIL_TOKEN_ROOT="${JAIL_DIR_TOKENS}/${ROOT_TOKEN_NAME}"

CONSUL_INSTANCE_CONFIG_DIR="${CONSUL_INSTANCE_SRC_DIR}/config"
CONSUL_INSTANCE_POLICY_DIR="${CONSUL_INSTANCE_SRC_DIR}/policy"

# CONSUL_CONFIG_TARGET="${CONSUL_INSTANCE_CONFIG_DIR}/${CONSUL_CONFIG_TARGET:-''}"

declare -A EFFECTIVE_INTERFACE=(
  [CONFIG_DIR_POLICY]=$CONFIG_DIR_POLICY
  [CONSUL_INSTANCE_CONFIG_DIR]=$CONSUL_INSTANCE_CONFIG_DIR
  [CONSUL_INSTANCE_POLICY_DIR]=$CONSUL_INSTANCE_POLICY_DIR
  [DATACENTER]=$DATACENTER
  [JAIL_DIR_TLS]=$JAIL_DIR_TLS
  [JAIL_DIR_TOKENS]=$JAIL_DIR_TOKENS
  [JAIL_KEY_GOSSIP]=$JAIL_KEY_GOSSIP
  [JAIL_TOKEN_ROOT]=$JAIL_TOKEN_ROOT

  # [CLIENT_NAME]=$CLIENT_NAME
  # [JAIL_DIR_TLS]=$JAIL_DIR_TLS
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
throw_missing_dir $JAIL_DIR_TLS 400 '@see https://github.com/nirv-ai/docs/tree/main/cfssl'
throw_missing_dir $CONFIG_DIR_POLICY 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'

######################## FNS
## reusable
validate_consul() {
  file_or_dir=${1:-'file or directory required for validation'}

  consule validate $1
}

## actions
create_gossip_key() {
  echo_debug 'creating gossip key'
  mkdir -p $JAIL_DIR_KEYS
  echo "encrypt = \"$(consul keygen)\"" >$JAIL_KEY_GOSSIP
}
create_root_token() {
  mkdir -p $JAIL_DIR_TOKENS
  consul acl bootstrap --format json >$JAIL_TOKEN_ROOT
}
create_policy() {
  policy=${1:?'policy name is required'}
  policy_path=${2:?'path to policy is required'}

  throw_missing_file $policy_path 400 'path to policy invalid'

  echo_debug "creating policy $policy"

  # -datacenter $DATA_CENTER
  consul acl policy create \
    -name "$policy" \
    -description "$policy" \
    -rules @$policy_path || true
}
create_policies() {
  local server_policies=$(get_filenames_in_dir_no_ext $CONFIG_DIR_POLICY/server)

  echo_debug "creating server policies: $server_policies"
  for policy in $server_policies; do
    create_policy $policy $CONFIG_DIR_POLICY/server/$policy.hcl
  done

  local service_policies=$(get_filenames_in_dir_no_ext $CONFIG_DIR_POLICY/service)

  echo_debug "creating service policies: $service_policies"
  for policy in $service_policies; do
    create_policy $policy $CONFIG_DIR_POLICY/service/$policy.hcl
  done

}
create_server_policy_tokens() {
  local server_policies=$(get_filenames_in_dir_no_ext $CONFIG_DIR_POLICY/server)

  echo_debug "creating tokens for policies: $server_policies"

  for policy in $server_policies; do
    consul acl token create \
      -policy-name="$policy" \
      -description="$policy" \
      --format json >$JAIL_DIR_TOKENS/token.$policy.json
  done
}
create_service_tokens() {
  local service_policies=$(get_filenames_in_dir_no_ext $CONFIG_DIR_POLICY/service)

  echo_debug "creating tokens for services: $service_policies"

  # consul acl token create \
  #   -node-identity="${svc_name}:us-east" \
  #   -service-identity="${svc_name}" \
  #   -policy-name="$policy_name" \
  #   -description="acl token for ${svc_name}" \
  #   --format json >${JAIL}/tokens/${svc_name}-acl.token.json 2>/dev/null

  # consul acl token create \
  #   -node-identity="core-proxy:us-east" \
  #   -service-identity="core-proxy" \
  #   -policy-name="acl-policy-core-proxy" \
  #   -description="acl token for core-proxy" \
  #   --format json >${JAIL}/tokens/core-proxy-acl.token.json 2>/dev/null

  # consul acl token create \
  #   -node-identity="core-vault:us-east" \
  #   -service-identity="core-vault" \
  #   -policy-name="acl-policy-core-vault" \
  #   -description="acl token for core-vault" \
  #   --format json >${JAIL}/tokens/core-vault-acl.token.json 2>/dev/null
}
get_root_token() {
  throw_missing_file $JAIL_TOKEN_ROOT 400 'cant find root token'
  echo $(cat $JAIL_TOKEN_ROOT | jq -r ".SecretID")
}

set_server_tokens() {
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
  agent-tokens) set_server_tokens ;;
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
  root-token) get_root_token ;;
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
  root-token) create_root_token ;;
  policies) create_policies ;;
  server-policy-tokens) create_server_policy_tokens ;;
  service-tokens) create_service_tokens ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
