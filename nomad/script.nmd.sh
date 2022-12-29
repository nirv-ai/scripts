#!/usr/bin/env bash

set -eu

NOMAD_ADDR_SUBD=${ENV:-mad}
NOMAD_ADDR_HOST=${NOMAD_ADDR_HOST:-nirv.ai}
NOMAD_SERVER_PORT="${NOMAD_SERVER_PORT:-4646}"
NOMAD_ADDR="${NOMAD_ADDR:-https://${NOMAD_ADDR_SUBD}.${NOMAD_ADDR_HOST}:${NOMAD_SERVER_PORT}}"
NOMAD_CACERT="${NOMAD_CACERT:-./tls/nomad-ca.pem}"
NOMAD_CLIENT_CERT="${NOMAD_CLIENT_CERT:-./tls/cli.pem}"
NOMAD_CLIENT_KEY="${NOMAD_CLIENT_KEY:-./tls/cli-key.pem}"

NOMAD_CMD_ARGS="-ca-cert=$NOMAD_CACERT -client-cert=$NOMAD_CLIENT_CERT -client-key=$NOMAD_CLIENT_KEY -address=$NOMAD_ADDR"

DEBUG=${NIRV_SCRIPT_DEBUG:-''}

nmd() {
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.NMD.SH\n------------'
    echo -e "[cmd]: $1\n[args]: ${@:2}\n------------\n\n"
  fi

  # dont process job init commands, as theres no config to validate/check
  if test "$*" = "${*#job init}"; then
    for arg in $@; do
      if [[ $arg = -config* || $arg = *.nomad ]]; then
        path=${arg#*=}
        echo -e "formatting file: $path"
        nomad fmt -check "$path"
        if [[ $arg = -config* ]]; then
          echo -e "validating file: $path"
          nomad config validate "$path"
        fi
      fi
    done
  fi

  # s = server, c = client
  case $1 in
  s | c)
    what=$(test "$1" = 'c' && echo 'client' || echo 'server')
    echo -e "starting $what: sudo -b nomad agent ${@:2}"
    sudo -b nomad agent "${@:2}"
    exit 0
    ;;
  esac

  case $1 in
  plan | status)
    echo
    echo -e "executing: sudo nomad $1 [tls-options] ${@:2}"
    sudo nomad "$1" $NOMAD_CMD_ARGS "${@:2}"
    ;;
  job | node | alloc | system)
    case $2 in
    run | status | logs | run | stop | gc)
      echo -e "executing: sudo nomad $1 $2 [tls-options] ${@:3}"
      echo
      sudo nomad "$1" "$2" $NOMAD_CMD_ARGS "${@:3}"
      ;;
    *) echo -e "cmd not setup for script.nmd.sh: $@ " ;;
    esac
    ;;
  *)
    # catch all: nomad expects TNOMAD_CMD_ARGS to come after nomad CMD ...
    echo -e "executing: sudo nomad $@ [tls-options]"
    sudo nomad "$@" $NOMAD_CMD_ARGS
    ;;
  esac

}

ENV=${ENV:-development}
nmdhelp='get|create|start|run|stop|rm|dockerlogs'
nmdcmd=${1:-help}

case $nmdcmd in
gc)
  nmd system gc
  ;;
start)
  what=${2:-""}
  case $what in
  s | c) nmd "${@:2}" ;;
  *)
    echo -e 'syntax: start [server|client] -config=x -config=y ....'
    exit 0
    ;;
  esac
  ;;
create)
  what=${2:-""}
  case $what in
  gossipkey)
    echo -e 'creating gossip encryption key'
    echo -e 'remember to update your job.nomad server block'
    nmd operator gossip keyring generate
    ;;
  job)
    name=${3:-""}
    if [[ -z $name ]]; then
      echo 'syntax: `create job jobName`'
      exit 1
    fi

    echo -e "creating new job $3.nomad in the current dir"
    nomad job init -short "$ENV.$name.nomad"
    echo -e "updating job name in $ENV.$name.nomad"
    sudo sed -i "/job \"example\"/c\job \"$name\" {" "./$ENV.$name.nomad"
    ;;
  *) echo -e "syntax: create job|gossipkey." ;;
  esac
  ;;
get)
  gethelp='get status|logs|plan'
  cmdname=${2:-""}
  if [[ -z $cmdname ]]; then
    echo -e $gethelp
    exit 1
  fi

  case $2 in
  status)
    opts='team|node|all|loc|dep|job'
    cmdhelp="get status of what? $opts"
    ofwhat=${3:-""}
    if [[ -z $ofwhat ]]; then
      echo -e $cmdhelp
      exit 1
    fi
    case $3 in
    team)
      echo -e "retrieving [server] members"
      nmd server members -detailed
      ;;
    node)
      nodeid=${4:-''}
      if [[ -z $nodeid ]]; then
        echo -e 'getting verbose server status'
        nmd node status -verbose
        exit 0
      fi
      echo -e "getting verbose status for node $nodeid"
      nmd node status -verbose $nodeid
      ;;
    all) nmd status ;;
    loc)
      id=${4:-""}
      if [[ -z $id ]]; then
        echo 'syntax: `get status loc allocId`'
        exit 1
      fi
      echo -e "getting status of allocation: $id"
      nmd alloc status -verbose -stats $id
      ;;
    dep)
      id=${4:-""}
      if [[ -z $id ]]; then
        echo 'syntax: `get status dep deployId`'
        exit 1
      fi
      echo -e "getting status of deployment: $id"
      nmd status $id
      ;;
    job)
      name=${4:-""}
      if [[ -z $name ]]; then
        echo 'syntax: `get status job jobName`'
        exit 1
      fi
      echo -e "getting status of $name"
      nmd job status $name
      ;;
    *) echo -e $cmdhelp ;;
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
    nmd alloc logs -f $id $name
    ;;
  plan)
    name=${3:-""}
    if [[ -z $name ]]; then
      echo 'syntax: `get plan jobName`'
      exit 1
    fi
    if test ! -f "$ENV.$name.nomad"; then
      echo -e "ensure jobspec $ENV.$name.nomad exists in current dir"
      echo -e 'create a new job plan with `create job jobName`'
      exit 1
    fi

    echo -e "creating job plan for $name"
    echo -e "\tto use this script to submit the job"
    echo -e "\texecute: run $name indexNumber"
    nmd plan -var-file=.env.$ENV.compose.json "$ENV.$name.nomad"
    ;;
  *) echo -e $gethelp ;;
  esac
  ;;
run)
  name=${2:-""}
  index=${3:-""}
  if [[ -z $name ]]; then
    echo -e 'syntax: `run jobName [jobIndex]`'
    exit 1
  fi
  if test ! -f "$ENV.$name.nomad"; then
    echo -e "ensure jobspec $ENV.$name.nomad exists in current dir"
    echo -e 'create a new job with `create job jobName`'
    exit 1
  fi
  if [[ -z $index ]]; then
    echo -e 'you should always use the jobIndex'
    echo -e 'get the job index: `get plan jobName`'
    echo -e 'syntax: `run jobName [jobIndex]`'
    echo -e "running job $name anyway :("
    nmd job run -var-file=.env.$ENV.compose.json $ENV.$name.nomad
    exit $?
  fi
  echo -e "running job $name at index $index"
  echo -e '\t job failures? get the allocation id from the job status'
  echo -e '\t execute: get status job jobName'
  echo -e '\t execute: get status loc allocId\n\n'
  nmd job run -check-index $index -var-file=.env.$ENV.compose.json $ENV.$name.nomad
  ;;
rm)
  name=${2:-""}
  if [[ -z $name ]]; then
    echo -e 'syntax: `rm jobName`'
    exit 1
  fi
  echo -e "purging job $name"
  nmd job stop -purge $name
  ;;
stop)
  name=${2:-""}
  if [[ -z $name ]]; then
    echo -e 'syntax: `stop jobName`'
    exit 1
  fi
  echo -e "stopping job $name"
  nmd job stop $name
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
*) echo -e $nmdhelp ;;
esac
