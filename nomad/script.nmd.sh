#!/usr/bin/env bash

set -euo pipefail

######################## SETUP
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/nomad/README.md'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# PLATFORM UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## INTERFACE
# grouped by increasing order of dependency
APP_IAC_NOMAD_DIR="${APP_IAC_NOMAD_DIR:-${APP_IAC_PATH}/nomad}"
export NOMAD_CACERT="${NOMAD_CACERT:-${CERTS_DIR_HOST}/${MAD_HOSTNAME}/ca.pem}"
export NOMAD_CLIENT_CERT="${NOMAD_CLIENT_CERT:-${CERTS_DIR_HOST}/${MAD_HOSTNAME}/cli-0.pem}"
export NOMAD_CLIENT_KEY="${NOMAD_CLIENT_KEY:-${CERTS_DIR_HOST}/${MAD_HOSTNAME}/cli-0-key.pem}"
JAIL_MAD_KEYS="${JAIL}/nomad/keys"
JAIL_MAD_TOKENS="${JAIL}/nomad/tokens"
NOMAD_CONF_CLIENT="${CONFIGS_DIR}/nomad/client"
NOMAD_CONF_GLOBALS="${CONFIGS_DIR}/nomad/global"
NOMAD_CONF_SERVER="${CONFIGS_DIR}/nomad/server"
NOMAD_CONF_STACKS="${CONFIGS_DIR}/nomad/stacks"
NOMAD_GOSSIP_FILENAME='server.gossip.key'
NOMAD_SERVER_PORT="${NOMAD_SERVER_PORT:-4646}"

export NOMAD_ADDR="${NOMAD_ADDR:-https://${MAD_HOSTNAME}:${NOMAD_SERVER_PORT}}"
JAIL_KEY_GOSSIP="${JAIL_MAD_KEYS}/${NOMAD_GOSSIP_FILENAME}"

# add vars that should be printed when NIRV_SCRIPT_DEBUG=1
declare -A EFFECTIVE_INTERFACE=(
  [APP_IAC_PATH]=$APP_IAC_PATH
  [DOCS_URI]=$DOCS_URI
  [JAIL_KEY_GOSSIP]=$JAIL_KEY_GOSSIP
  [NOMAD_ADDR]=$NOMAD_ADDR
  [NOMAD_CACERT]=$NOMAD_CACERT
  [NOMAD_CLIENT_CERT]=$NOMAD_CLIENT_CERT
  [NOMAD_CLIENT_KEY]=$NOMAD_CLIENT_KEY
  [NOMAD_CONF_CLIENT]=$NOMAD_CONF_CLIENT
  [NOMAD_CONF_GLOBALS]=$NOMAD_CONF_GLOBALS
  [NOMAD_CONF_SERVER]=$NOMAD_CONF_SERVER
  [NOMAD_CONF_STACKS]=$NOMAD_CONF_STACKS
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
)

######################## CREDIT CHECK
echo_debug_interface

# add aditional checks and balances below this line
# use standard http response codes
throw_missing_dir $SCRIPTS_DIR_PARENT 500 "somethings wrong: cant find myself in filesystem"
throw_missing_file $NOMAD_CACERT 400 "all cmds require cert auth pem"
throw_missing_file $NOMAD_CLIENT_CERT 400 "all cmds require cli pem"
throw_missing_file $NOMAD_CLIENT_KEY 400 "all cmds require cli key pem"

######################## FNS
kill_nomad_service() {
  # requires shell-init/services.sh
  # TODO: this doesnt kill the client; only the server
  request_sudo 'kill service with name nomad'
  kill_service_by_name nomad || true
}
sync_local_configs() {
  use_hashi_fmt || true

  local client_configs=(
    $NOMAD_CONF_CLIENT
    $NOMAD_CONF_GLOBALS
  )

  local server_configs=(
    $NOMAD_CONF_GLOBALS
    $NOMAD_CONF_SERVER
  )

  echo_debug 'syncing nomad server confs'
  local iac_server_dir="${APP_IAC_NOMAD_DIR}/server"
  mkdir -p $iac_server_dir
  for server_conf in "${server_configs[@]}"; do
    cp_to_dir $server_conf $iac_server_dir
  done

  echo_debug 'syncing nomad server confs'
  local iac_client_dir="${APP_IAC_NOMAD_DIR}/client"
  mkdir -p $iac_client_dir
  for client_conf in "${client_configs[@]}"; do
    cp_to_dir $client_conf $iac_client_dir
  done

  echo_debug 'copying nomad stacks'
  local iac_stacks_dir="${APP_IAC_NOMAD_DIR}/stacks"
  mkdir -p $iac_stacks_dir
  cp_to_dir $NOMAD_CONF_STACKS $iac_stacks_dir
}
create_gossip_key() {
  echo_debug 'creating gossip key'
  mkdir -p $JAIL_MAD_KEYS
  nomad operator gossip keyring generate >$JAIL_KEY_GOSSIP
}
create_new_stack() {
  name=${1:?stack name required}

  echo_debug "creating new stack $name.nomad"
  nomad job init -short "$name.nomad"

  echo_debug "updating stack name in $name.nomad"
  sed -i "/job \"example\"/c\job \"$name\" {" "$name.nomad"

  echo_debug "moving stack $name.nomad to configs"
  mv $name.nomad $NOMAD_CONF_STACKS/$name.nomad

  echo_debug "syncing nomad configs"
  sync_local_configs
}
get_stack_plan() {
  name=${1:?stack name required}
  # TODO: this should be APP_IAC_PATH when working
  stack_file="${NOMAD_CONF_STACKS}/${name}.nomad"
  env_file="${SCRIPTS_DIR_PARENT}/$name/.env.compose.json"

  throw_missing_file $stack_file 404 'stack file doesnt exist'
  throw_missing_file $env_file 404 'env file doesnt exist'

  echo_debug "creating job plan for $name"
  echo_info "execute this plan: run $name indexNumber"
  nomad plan -var-file=$env_file "$stack_file"
}
run_stack() {
  name=${1:?stack name required}
  index=${2:?index required}

  # TODO: this should be APP_IAC_PATH when working
  stack_file="${NOMAD_CONF_STACKS}/${name}.nomad"
  env_file="${SCRIPTS_DIR_PARENT}/$name/.env.compose.json"

  throw_missing_file $stack_file 404 'stack file doesnt exist'
  throw_missing_file $env_file 404 'env file doesnt exist'

  echo_debug "running stack $name at index $index"
  echo_debug '\t job failures? get the allocation id from the job status'
  echo_debug '\t execute: get status job jobName'
  echo_debug '\t execute: get status loc allocId\n\n'
  nomad job run -check-index $index -var-file=$env_file "$stack_file"
}
######################## EXECUTE

# nomad alloc fs locId [dirName]
# nomad alloc exec
# nomad acl policy apply
# nomad operator autopilot get-config

cmd=${1:-''}
case $cmd in
sync-confs) sync_local_configs ;;
kill) kill_nomad_service ;;
gc)
  nomad system gc
  ;;
start)
  type=${2:-''}
  total=1 #${3:-1}
  conf_dir="$APP_IAC_NOMAD_DIR/$type"
  throw_missing_dir $conf_dir 400 "$conf_dir doesnt exist"

  # TODO: we need to add -dev-connect
  case $type in
  server)
    request_sudo "starting $total nomad $type agent(s)"
    declare -i i=0
    while [ $i -lt $total ]; do
      name=s$i
      sudo -b nomad agent \
        -bootstrap-expect=$total \
        -config=$conf_dir \
        -data-dir=/tmp/nomad/$name \
        -encrypt=$(cat $JAIL_KEY_GOSSIP) \
        -node=$type-$name.$(hostname) \
        -server
      i=$((i + 1))
    done
    ;;
  client)
    request_sudo "starting $total nomad $type agent(s)"
    declare -i i=0
    while [ $i -lt $total ]; do
      name=c$i
      sudo -b nomad agent \
        -client \
        -config=$conf_dir \
        -data-dir=/tmp/nomad/$name \
        -node=$type-$name.$(hostname)
      i=$((i + 1))
    done
    ;;
  *) invalid_request ;;
  esac
  ;;
create)
  what=${2:-""}
  case $what in
  gossipkey) create_gossip_key ;;
  stack) create_new_stack ${3:?stack name required} ;;
  *) invalid_request ;;
  esac
  ;;
get)
  cmdname=${2:-''}
  case $2 in
  status)
    of=${3:-''}
    case $of in
    servers)
      echo_debug "retrieving server(s) status"
      nomad server members -detailed
      ;;
    clients)
      nodeid=${4:-''}
      if test -z $nodeid; then
        echo_debug 'retrieving client(s) status'
        nomad node status -verbose
      else
        # $nodeid can be -self
        echo_debug "retrieving status for client $nodeid"
        nomad node status -verbose $nodeid
      fi
      ;;
    all) nomad status ;;
    loc)
      id=${4:?allocation id required}
      echo_debug "getting status of allocation: $id"
      nomad alloc status -verbose -stats $id
      ;;
    dep)
      id=${4:?deployment id required}
      echo_debug "getting status of deployment: $id"
      nomad status $id
      ;;
    stack)
      name=${4:?stack name required}
      echo -e "getting status of $name"
      nomad job status $name
      ;;
    *) invalid_request ;;
    esac
    ;;
  logs)
    name=${3:-""}
    id=${4:-""}
    if [[ -z $name || -z id ]]; then
      echo -e 'syntax: `get logs taskName allocId`'
      exit 1
    fi
    echo -e "fetching logs for task $name in allocation $id"
    nomad alloc logs -f $id $name
    ;;
  plan) get_stack_plan ${3:?stack name required} ;;
  *) invalid_request ;;
  esac
  ;;
run) run_stack ${2:?stack name required} ${3:?job index required} ;;
rm)
  name=${2:-""}
  if [[ -z $name ]]; then
    echo -e 'syntax: `rm jobName`'
    exit 1
  fi
  echo_info "purging job $name"
  nomad job stop -purge $name || true
  ;;
stop)
  name=${2:-""}
  if [[ -z $name ]]; then
    echo -e 'syntax: `stop jobName`'
    exit 1
  fi
  echo -e "stopping job $name"
  nomad job stop $name
  ;;
dockerlogs)
  # @see https://stackoverflow.com/questions/36756751/view-logs-for-all-docker-containers-simultaneously
  echo -e 'following logs for all running containers'
  echo -e 'be sure to delete /tmp directory every so often'
  for c in $(docker ps -a --format="{{.Names}}"); do
    docker logs -f $c >/tmp/$c.log 2>/tmp/$c.err &
  done
  tail -f /tmp/*.{log,err}
  ;;
*) invalid_request ;;
esac
