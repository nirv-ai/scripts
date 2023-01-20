#!/usr/bin/env bash

set -euo pipefail

# consul cmd cmd cmd --help has wonderful examples, thank me later
######################## SETUP
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/consul/README.md'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## INTERFACE
# group by increasing order of dependency

CONSUL_APP_SRC_PATH='src/consul'
CONSUL_CONF_CLIENT="${CONFIGS_DIR}/consul/client"
CONSUL_CONF_DEFAULTS="${CONFIGS_DIR}/consul/defaults"
CONSUL_CONF_GLOBALS="${CONFIGS_DIR}/consul/global"
CONSUL_CONF_INTENTS="${CONFIGS_DIR}/consul/intention"
CONSUL_CONF_POLICY="${CONFIGS_DIR}/consul/policy"
CONSUL_CONF_SERVER="${CONFIGS_DIR}/consul/server"
CONSUL_CONF_SERVICE="${CONFIGS_DIR}/consul/service"
CONSUL_DIR_CERTS="${CERTS_DIR_HOST}/${MESH_HOSTNAME}"
CONSUL_GOSSIP_FILENAME='config.global.gossip.hcl'
CONSUL_SERVER_APP_NAME='core-consul'
CONSUL_SERVER_NODE_PREFIX='consul'
DATA_CENTER='us-east'
DNS_TOKEN_NAME='acl-policy-dns'
JAIL_MESH_KEYS="${JAIL}/consul/keys"
JAIL_MESH_TOKENS="${JAIL}/consul/tokens"
ROOT_TOKEN_NAME='root'
SERVER_TOKEN_NAME='acl-policy-consul'

JAIL_KEY_GOSSIP="${JAIL_MESH_KEYS}/${CONSUL_GOSSIP_FILENAME}"
JAIL_TOKEN_POLICY_DNS="${JAIL_MESH_TOKENS}/token.${DNS_TOKEN_NAME}.json"
JAIL_TOKEN_POLICY_SERVER="${JAIL_MESH_TOKENS}/token.${SERVER_TOKEN_NAME}.json"
JAIL_TOKEN_ROOT="${JAIL_MESH_TOKENS}/token.${ROOT_TOKEN_NAME}.json"

declare -A EFFECTIVE_INTERFACE=(
  [CONSUL_APP_SRC_PATH]=$CONSUL_APP_SRC_PATH
  [CONSUL_CONF_CLIENT]=$CONSUL_CONF_CLIENT
  [CONSUL_CONF_DEFAULTS]=$CONSUL_CONF_DEFAULTS
  [CONSUL_CONF_GLOBALS]=$CONSUL_CONF_GLOBALS
  [CONSUL_CONF_INTENTS]=$CONSUL_CONF_INTENTS
  [CONSUL_CONF_POLICY]=$CONSUL_CONF_POLICY
  [CONSUL_CONF_SERVER]=$CONSUL_CONF_SERVER
  [CONSUL_CONF_SERVICE]=$CONSUL_CONF_SERVICE
  [CONSUL_DIR_CERTS]=$CONSUL_DIR_CERTS
  [CONSUL_SERVER_NODE_PREFIX]=$CONSUL_SERVER_NODE_PREFIX
  [DATA_CENTER]=$DATA_CENTER
  [JAIL_KEY_GOSSIP]=$JAIL_KEY_GOSSIP
  [JAIL_MESH_TOKENS]=$JAIL_MESH_TOKENS
  [JAIL_TOKEN_POLICY_DNS]=$JAIL_TOKEN_POLICY_DNS
  [JAIL_TOKEN_POLICY_SERVER]=$JAIL_TOKEN_POLICY_SERVER
  [JAIL_TOKEN_ROOT]=$JAIL_TOKEN_ROOT
)

######################## CREDIT CHECK
echo_debug_interface

throw_missing_program consul 404 '@see https://developer.hashicorp.com/consul/downloads'
throw_missing_program jq 404 '@see https://stedolan.github.io/jq/'
throw_missing_program nomad 404 "@see https://developer.hashicorp.com/nomad/tutorials/get-started/get-started-install"

throw_missing_dir $CONSUL_CONF_CLIENT 404 '@see https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONSUL_CONF_GLOBALS 404 '@see https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONSUL_CONF_INTENTS 404 '@see https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONSUL_CONF_POLICY 404 '@see https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONSUL_CONF_SERVER 404 '@see https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONSUL_CONF_SERVICE 404 '@see https://github.com/nirv-ai/configs/tree/develop/consul'
throw_missing_dir $CONSUL_DIR_CERTS 404 '@see https://github.com/nirv-ai/docs/tree/main/cfssl'
throw_missing_dir $JAIL 404 "mkdir -p $JAIL"

######################## FNS
## reusable
validate_consul() {
  # this needs to work on the *full* set of conf files
  # that will be used by an agent
  file_or_dir=${1:-'file or directory required for validation'}

  consul validate $1
}

## actions
create_gossip_key() {
  echo_debug 'creating gossip key'
  mkdir -p $JAIL_MESH_KEYS
  echo "encrypt = \"$(consul keygen)\"" >$JAIL_KEY_GOSSIP
}
create_root_token() {
  mkdir -p $JAIL_MESH_TOKENS
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
  local server_policies=$(get_filenames_in_dir_no_ext $CONSUL_CONF_POLICY/server)

  echo_debug "creating server policies: $server_policies"
  for policy in $server_policies; do
    create_policy $policy $CONSUL_CONF_POLICY/server/$policy.hcl
  done

  local service_policies=$(get_filenames_in_dir_no_ext $CONSUL_CONF_POLICY/service)

  echo_debug "creating service policies: $service_policies"
  for policy in $service_policies; do
    create_policy $policy $CONSUL_CONF_POLICY/service/$policy.hcl
  done
}
create_config() {
  config_path=${1:?config path required}
  throw_missing_file $config_path 400 'invalid path to config file'

  consul config write $config_path
}
create_intentions() {
  for conf in $CONSUL_CONF_INTENTS/*; do
    test -f $conf || break

    create_config $conf
  done
}
create_defaults() {
  for conf in $CONSUL_CONF_DEFAULTS/*; do
    test -f $conf || break

    create_config $conf
  done
}
# TODO: this should call create_token
create_server_policy_tokens() {
  local server_policies=$(get_filenames_in_dir_no_ext $CONSUL_CONF_POLICY/server)

  echo_debug "creating tokens for policies: $server_policies"

  mkdir -p $JAIL_MESH_TOKENS
  for policy in $server_policies; do
    consul acl token create \
      -policy-name="$policy" \
      -description="$policy" \
      --format json >$JAIL_MESH_TOKENS/token.$policy.json
  done
}
# TODO: this should call create_token
create_service_policy_tokens() {
  local service_policies=$(get_filenames_in_dir_no_ext $CONSUL_CONF_POLICY/service)

  echo_debug "creating tokens for services: $service_policies"

  mkdir -p $JAIL_MESH_TOKENS
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
      --format json >${JAIL_MESH_TOKENS}/token.$svc_name.json 2>/dev/null
  done
}
# an operator/developer may not have read on tokens API
# this is for retrieving tokens from a file
get_token_from_file() {
  token_name_or_file=${1:-'token filepath or name is required'}
  case $token_name_or_file in
  *.json)
    throw_missing_file $token_name_or_file 400 "token file not found: $token_name_or_file"
    echo $(cat $token_name_or_file | jq -r ".SecretID")
    ;;
  *)
    local token_file="${JAIL_MESH_TOKENS}/token.${token_name_or_file}.json"
    throw_missing_file $token_file 400 "token file not found:\n$token_file"
    echo $(cat $token_file | jq -r ".SecretID")
    ;;
  esac
}
set_server_tokens() {
  echo_debug "setting tokens: wait for validation"
  # the below swallows the errors
  dns_token=$(get_token_from_file $JAIL_TOKEN_POLICY_DNS)
  server_token=$(get_token_from_file $JAIL_TOKEN_POLICY_SERVER)

  # will log success if the above didnt exit
  # but success doesnt mean the acls/tokens are configured properly
  # just that they were set, lol
  consul acl set-agent-token default "$dns_token"
  consul acl set-agent-token agent "$server_token"

}
sync_local_configs() {
  use_hashi_fmt || true

  local client_configs=(
    $CONSUL_CONF_CLIENT
    $CONSUL_CONF_GLOBALS
    $JAIL_KEY_GOSSIP
  )

  local server_configs=(
    $CONSUL_CONF_GLOBALS
    $CONSUL_CONF_SERVER
    $JAIL_KEY_GOSSIP
  )
  local services="$CONSUL_CONF_SERVICE"

  echo_debug "syncing server if found: $CONSUL_SERVER_APP_NAME"
  local server_app_config_dir="$(get_app_dir $CONSUL_SERVER_APP_NAME $CONSUL_APP_SRC_PATH/config)"
  if test -d "$server_app_config_dir"; then
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

    local svc_app=$(get_app_dir $(basename $srv_conf) $CONSUL_APP_SRC_PATH)
    echo_debug "service found: $svc_app"

    cp_to_dir $srv_conf/config "$svc_app/config"
    cp_to_dir $srv_conf/envoy "$svc_app" 'replace entire envoy directory'

    for client_conf in "${client_configs[@]}"; do
      cp_to_dir $client_conf "$svc_app/config"
    done

    request_sudo "$(basename $svc_app) app: setting ownership to consul:consul"
    sudo chown -R consul:consul $svc_app/config
    sudo chown -R consul:consul $svc_app/envoy
    validate_consul $svc_app/config || true # dont fail if error
  done
}
sync_env_auto() {
  local services="$CONSUL_CONF_SERVICE"

  echo_debug "syncing server env if found: $CONSUL_SERVER_APP_NAME $CONSUL_SERVER_NODE_PREFIX $APP_ENV_AUTO"
  local server_app_root_dir="$(get_app_root $CONSUL_SERVER_APP_NAME)"
  if test -d "$server_app_root_dir" && test -n "$CONSUL_SERVER_NODE_PREFIX"; then
    env_auto_path="$server_app_root_dir/$APP_ENV_AUTO"

    echo_debug "syncing: $env_auto_path"

    if test ! -f "$env_auto_path"; then
      echo '# managed by NIRV SCRIPTS' >$env_auto_path
    fi

    # delete any matching lines
    sed -i '/^CONSUL_HTTP_TOKEN/d;/CONSUL_DNS_TOKEN/d;/CONSUL_NODE_PREFIX/d' $env_auto_path
    # add new lines
    sed -i "\$aCONSUL_DNS_TOKEN=$(get_token_from_file $JAIL_TOKEN_POLICY_DNS)" $env_auto_path
    sed -i "\$aCONSUL_HTTP_TOKEN=$(get_token_from_file $JAIL_TOKEN_POLICY_SERVER)" $env_auto_path
    sed -i "\$aCONSUL_NODE_PREFIX=$CONSUL_SERVER_NODE_PREFIX" $env_auto_path
  fi

  echo_debug "syncing service(s) if any:\n$services/*"
  for srv_conf in $services/*; do
    test -d $srv_conf || break

    local service_app_name=$(basename $srv_conf)
    local service_app_root_dir=$(get_app_root $service_app_name)

    env_auto_path="$service_app_root_dir/$APP_ENV_AUTO"

    echo_debug "syncing: $env_auto_path"

    if test ! -f "$env_auto_path"; then
      echo '# managed by NIRV SCRIPTS' >$env_auto_path
    fi

    # delete any matching lines
    sed -i '/^CONSUL_HTTP_TOKEN/d;/CONSUL_NODE_PREFIX/d' $env_auto_path
    # add new lines
    sed -i "\$aCONSUL_HTTP_TOKEN=$(get_token_from_file $service_app_name)" $env_auto_path
    sed -i "\$aCONSUL_NODE_PREFIX=$service_app_name" $env_auto_path
  done
}

cmd=${1:-''}

case $cmd in
sync-confs) sync_local_configs ;;
sync-env-auto) sync_env_auto ;;
reload) consul reload ;;
validate)
  what=${2:-'hcl'}
  case $what in
  hcl) use_hashi_fmt ;;
  *) validate_consul $what ;;
  esac
  ;;
set)
  what=${2:?''}

  case $what in
  server-tokens) set_server_tokens ;; # you should prefer sync-env-auto
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
  cli-env) echo "source $CONFIGS_DIR/consul/.env.cli" ;;
  info) consul info ;;
  team) consul members ;;
  nodes) consul catalog nodes -detailed ;;
  policy) consul acl policy read -id ${3:?'policy id required: use `list policies`'} ;;
  token-info) consul acl token read -id ${3:?'token axor id required: use `list tokens`'} ;;
  root-token)
    if test -f $JAIL_TOKEN_ROOT; then
      get_token_from_file $JAIL_TOKEN_ROOT
    fi
    ;;
  dns-token) get_token_from_file $JAIL_TOKEN_POLICY_DNS ;;
  server-token) get_token_from_file $JAIL_TOKEN_POLICY_SERVER ;;
  token) get_token_from_file $3 ;;
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
  defaults) create_defaults ;;
  server-policy-tokens) create_server_policy_tokens ;;
  service-policy-tokens) create_service_policy_tokens ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
