#!/usr/bin/env bash

set -euo pipefail

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/consul/README.md'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# grouped by increasing order of dependency
APP_PREFIX='nirvai'
CONFIGS_DIR_NAME=configs
CONSUL_INSTANCES_SRC_PATH='src/consul' # will contain e.g. {config,envoy,data}
CONSUL_SERVER_APP_NAME='core-consul'
DATA_CENTER=us-east
DNS_TOKEN_NAME=acl-policy-dns
GOSSIP_KEY_NAME='config.global.gossip.hcl'
JAIL="${SCRIPTS_DIR_PARENT}/secrets"
MESH_HOSTNAME=mesh.nirv.ai
REPO_DIR="${SCRIPTS_DIR_PARENT}/core"
ROOT_TOKEN_NAME=root
SERVER_TOKEN_NAME=acl-policy-consul

APPS_DIR="${REPO_DIR}/apps"
CONFIG_DIR_CLIENT="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/client"
CONFIG_DIR_GLOBAL="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/global"
CONFIG_DIR_INTENTION="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/intention"
CONFIG_DIR_POLICY="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/policy"
CONFIG_DIR_SERVER="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/server"
CONFIG_DIR_SERVICE="${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}/consul/service"
JAIL_DIR_KEYS="${JAIL}/consul/keys"
JAIL_DIR_TLS="${JAIL}/${MESH_HOSTNAME}/tls"
JAIL_DIR_TOKENS="${JAIL}/consul/tokens"

JAIL_KEY_GOSSIP="${JAIL_DIR_KEYS}/${GOSSIP_KEY_NAME}"
JAIL_TOKEN_POLICY_DNS="${JAIL_DIR_TOKENS}/token.${DNS_TOKEN_NAME}.json"
JAIL_TOKEN_POLICY_SERVER="${JAIL_DIR_TOKENS}/token.${SERVER_TOKEN_NAME}.json"
JAIL_TOKEN_ROOT="${JAIL_DIR_TOKENS}/token.${ROOT_TOKEN_NAME}.json"

declare -A EFFECTIVE_INTERFACE=(
  [CONFIG_DIR_CLIENT]=$CONFIG_DIR_CLIENT
  [CONFIG_DIR_GLOBAL]=$CONFIG_DIR_GLOBAL
  [CONFIG_DIR_INTENTION]=$CONFIG_DIR_INTENTION
  [CONFIG_DIR_POLICY]=$CONFIG_DIR_POLICY
  [CONFIG_DIR_SERVER]=$CONFIG_DIR_SERVER
  [CONFIG_DIR_SERVICE]=$CONFIG_DIR_SERVICE
  [CONSUL_INSTANCES_SRC_PATH]=$CONSUL_INSTANCES_SRC_PATH
  [DATA_CENTER]=$DATA_CENTER
  [JAIL_DIR_TLS]=$JAIL_DIR_TLS
  [JAIL_DIR_TOKENS]=$JAIL_DIR_TOKENS
  [JAIL_KEY_GOSSIP]=$JAIL_KEY_GOSSIP
  [JAIL_TOKEN_POLICY_DNS]=$JAIL_TOKEN_POLICY_DNS
  [JAIL_TOKEN_POLICY_SERVER]=$JAIL_TOKEN_POLICY_SERVER
  [JAIL_TOKEN_ROOT]=$JAIL_TOKEN_ROOT
)

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## CREDIT CHECK
echo_debug_interface

throw_missing_program consul 400 '@see https://developer.hashicorp.com/consul/downloads'
throw_missing_program jq 400 'sudo apt install jq'
throw_missing_program nomad 400 "@see https://developer.hashicorp.com/nomad/tutorials/get-started/get-started-install"

throw_missing_dir $JAIL 400 "mkdir -p $JAIL"
throw_missing_dir $JAIL_DIR_TLS 400 '@see https://github.com/nirv-ai/docs/tree/main/cfssl'
throw_missing_dir $CONFIG_DIR_CLIENT 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONFIG_DIR_GLOBAL 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONFIG_DIR_INTENTION 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONFIG_DIR_POLICY 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONFIG_DIR_SERVER 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONFIG_DIR_SERVICE 400 'create or copy from: https://github.com/nirv-ai/configs/tree/develop/consul'

######################## FNS
## reusable
validate_consul() {
  # this needs to work on the *full* set of conf files
  # that will be used by an agent
  file_or_dir=${1:-'file or directory required for validation'}

  consul validate $1
}
use_nomad_fmt() {
  local conf_dir=${SCRIPTS_DIR_PARENT}/${CONFIGS_DIR_NAME}
  echo_debug "formatting hcl in $conf_dir"

  nomad fmt -list=true -check -write=true -recursive $conf_dir
}
get_app_dir() {
  svc_name=${1:?service name is required}

  echo "${APPS_DIR}/${APP_PREFIX}-$svc_name/${CONSUL_INSTANCES_SRC_PATH}"
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
sync_local_configs() {
  use_nomad_fmt || true

  local client_configs=(
    $CONFIG_DIR_CLIENT
    $CONFIG_DIR_GLOBAL
    $JAIL_KEY_GOSSIP
  )
  local server_configs=(
    $CONFIG_DIR_GLOBAL
    $CONFIG_DIR_SERVER
    $JAIL_KEY_GOSSIP
  )
  local services="$CONFIG_DIR_SERVICE"

  echo_debug "syncing server if found: $CONSUL_SERVER_APP_NAME"
  if test -d "$CONSUL_SERVER_APP_NAME"; then
    local server_app_config_dir="$(get_app_dir $CONSUL_SERVER_APP_NAME)/config"

    echo_debug "server confs:\n${server_configs[@]}"
    echo_debug "syncing: $server_app_config_dir"

    for server_conf in "${server_configs[@]}"; do
      cp_to_dir $server_conf $server_app_config_dir
    done

    request_sudo "setting ownership to consul:consul: $server_app_config_dir"
    sudo chown -R consul:consul $server_app_config_dir
    validate_consul $server_app_config_dir || true # dont fail if error
  fi

  echo_debug "syncing service(s) if any:\n$services\nclient confs:\n${client_configs[@]}"
  for srv_conf in $services/*; do
    test -d $srv_conf || break

    local svc_app=$(get_app_dir $(basename $srv_conf))
    echo_debug "service found: $svc_app"

    cp_to_dir $srv_conf/config "$svc_app/config"
    cp_to_dir $srv_conf/envoy "$svc_app" 'replace entire envoy directory'

    for client_conf in "${client_configs[@]}"; do
      cp_to_dir $client_conf "$svc_app/config"
    done

    request_sudo "$(basename $svc_app) app: setting ownership to consul:consul"
    sudo chown -R consul:consul $svc_app
    validate_consul $svc_app/config || true # dont fail if error
  done
}
## todo
# consul kv put consul/configuration/db_port 5432
# consul kv get consul/configuration/db_port
# dig @127.0.0.1 -p 8600 consul.service.consul
# consul catalog services -tags
# consul services register svc-db.hcl
# curl 172.17.0.1:8500/v1/status/leader  #get the leader
# consul cmd cmd cmd --help has wonderful examples, thank me later
# curl --request GET http://127.0.0.1:8500/v1/agent/checks

cmd=${1:-''}

case $cmd in
sync-confs) sync_local_configs ;;
reload) consul reload ;;
validate)
  what=${2:-'hcl'}
  case $what in
  hcl) use_nomad_fmt ;;
  *) validate_consul $what ;;
  esac
  ;;
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
