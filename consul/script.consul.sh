#!/usr/bin/env bash

set -euo pipefail

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/consul/README.md'
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-0}"
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# grouped by increasing order of dependency
APP_PREFIX='nirvai'
CONFIGS_DIR_NAME=configs
CONSUL_INSTANCE_DIR_NAME='core-consul'
CONSUL_SERVICE_NAME=core-consul
DATA_CENTER=us-east
GOSSIP_KEY_NAME='config.consul.gossip.hcl'
JAIL="${SCRIPTS_DIR_PARENT}/secrets"
MESH_HOSTNAME=mesh.nirv.ai
REPO_DIR="${SCRIPTS_DIR_PARENT}/core"
ROOT_TOKEN_NAME=root
DNS_TOKEN_NAME=acl-policy-dns
SERVER_TOKEN_NAME=acl-policy-consul

APPS_DIR="${REPO_DIR}/apps"
CONFIG_DIR_INTENTION="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/intention"
CONFIG_DIR_POLICY="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/policy"
JAIL_DIR_KEYS="${JAIL}/consul/keys"
JAIL_DIR_TLS="${JAIL}/${MESH_HOSTNAME}/tls"
JAIL_DIR_TOKENS="${JAIL}/consul/tokens"

CONSUL_INSTANCE_SRC_DIR="${APPS_DIR}/${APP_PREFIX}-${CONSUL_INSTANCE_DIR_NAME}/src"
JAIL_KEY_GOSSIP="${JAIL_DIR_KEYS}/${GOSSIP_KEY_NAME}"
JAIL_TOKEN_ROOT="${JAIL_DIR_TOKENS}/token.${ROOT_TOKEN_NAME}.json"
JAIL_TOKEN_POLICY_DNS="${JAIL_DIR_TOKENS}/token.${DNS_TOKEN_NAME}.json"
JAIL_TOKEN_POLICY_SERVER="${JAIL_DIR_TOKENS}/token.${SERVER_TOKEN_NAME}.json"
CONSUL_INSTANCE_CONFIG_DIR="${CONSUL_INSTANCE_SRC_DIR}/config"
CONSUL_INSTANCE_POLICY_DIR="${CONSUL_INSTANCE_SRC_DIR}/policy"

# CONSUL_CONFIG_TARGET="${CONSUL_INSTANCE_CONFIG_DIR}/${CONSUL_CONFIG_TARGET:-''}"

declare -A EFFECTIVE_INTERFACE=(
  [CONFIG_DIR_INTENTION]=$CONFIG_DIR_INTENTION
  [CONFIG_DIR_POLICY]=$CONFIG_DIR_POLICY
  [CONSUL_INSTANCE_CONFIG_DIR]=$CONSUL_INSTANCE_CONFIG_DIR
  [CONSUL_INSTANCE_POLICY_DIR]=$CONSUL_INSTANCE_POLICY_DIR
  [DATA_CENTER]=$DATA_CENTER
  [JAIL_DIR_TLS]=$JAIL_DIR_TLS
  [JAIL_DIR_TOKENS]=$JAIL_DIR_TOKENS
  [JAIL_KEY_GOSSIP]=$JAIL_KEY_GOSSIP
  [JAIL_TOKEN_POLICY_DNS]=$JAIL_TOKEN_POLICY_DNS
  [JAIL_TOKEN_POLICY_SERVER]=$JAIL_TOKEN_POLICY_SERVER
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

  # -DATA_CENTER $DATA_CENTER
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
create_intention() {
  intention_path=${1:?intention path required}
  throw_missing_file $intention_path 400 'invalid path to intention'

  consul config write $intention_path
}
create_intentions() {
  for intention in $CONFIG_DIR_INTENTION/*; do
    test -f $intention || break

    create_intention $intention
  done
}
# TODO: this should call create_token
create_server_policy_tokens() {
  local server_policies=$(get_filenames_in_dir_no_ext $CONFIG_DIR_POLICY/server)

  echo_debug "creating tokens for policies: $server_policies"

  mkdir -p $JAIL_DIR_TOKENS
  for policy in $server_policies; do
    consul acl token create \
      -policy-name="$policy" \
      -description="$policy" \
      --format json >$JAIL_DIR_TOKENS/token.$policy.json
  done
}
# TODO: this should call create_token
create_service_policy_tokens() {
  local service_policies=$(get_filenames_in_dir_no_ext $CONFIG_DIR_POLICY/service)

  echo_debug "creating tokens for services: $service_policies"

  mkdir -p $JAIL_DIR_TOKENS
  for policy in $service_policies; do
    # type-policy-svc-name > svc-name
    local svc_name=${policy#*-*-}
    echo_debug "create token $policy for $svc_name:$DATA_CENTER"

    # TODO: might need to add $DATA_CENTER to filename
    consul acl token create \
      -node-identity="$svc_name:$DATA_CENTER" \
      -service-identity="$svc_name" \
      -policy-name="$policy" \
      -description="$policy:$DATA_CENTER" \
      --format json >${JAIL_DIR_TOKENS}/token.$svc_name.json 2>/dev/null
  done
}
get_token() {
  throw_missing_file $1 400 'cant find token file'
  echo $(cat $1 | jq -r ".SecretID")
}

set_server_tokens() {
  echo -e "setting tokens: wait for validation"
  # the below swallows the errors
  dns_token=$(get_token $JAIL_TOKEN_POLICY_DNS)
  server_token=$(get_token $JAIL_TOKEN_POLICY_SERVER)

  # will log success if the above didnt exit
  # but success doesnt mean the acls/tokens are configured properly
  # just that they were set, lol
  consul acl set-agent-token default "$dns_token"
  consul acl set-agent-token agent "$server_token"

}
## todo
# consul kv put consul/configuration/db_port 5432
# consul kv get consul/configuration/db_port
# dig @127.0.0.1 -p 8600 consul.service.consul
# consul catalog services -tags
# consul services register svc-db.hcl
# curl 172.17.0.1:8500/v1/status/leader  #get the leader
# consul cmd cmd cmd --help has wonderful examples, thank me later
cmd=${1:-''}

case $cmd in
reload) consul reload ;;
set)
  what=${2:?''}

  case $what in
  server-tokens) set_server_tokens ;;
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
  info) consul info ;;
  team) consul members ;;
  nodes) consul catalog nodes -detailed ;;
  policy) consul acl policy read -id ${3:?'policy id required: use `list policies`'} ;;
  token-info) consul acl token read -id ${3:?'token axor id required: use `list tokens`'} ;;
  root-token) get_token $JAIL_TOKEN_ROOT ;;
  dns-token) get_token $JAIL_TOKEN_POLICY_DNS ;;
  server-token) get_token $JAIL_TOKEN_POLICY_SERVER ;;
  service-token)
    svc_name=${3:?'svc_name required'}
    get_token ${JAIL_DIR_TOKENS}/token.${svc_name}.json
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
  intentions) create_intentions ;;
  server-policy-tokens) create_server_policy_tokens ;;
  service-policy-tokens) create_service_policy_tokens ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
