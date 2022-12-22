#!/usr/bin/env bash

set -eu

nmd() {
  for arg in $@; do
    if [[ $arg = -config* || $arg = *.nomad ]]; then
      path=${arg#*=}
      echo -e "formatting and validating file: $path"
      nomad fmt -check "$path"
      if [[ $arg = -config* ]]; then
        nomad config validate "$path"
      fi
    fi
  done

  echo -e "running: nomad $@"
  echo ""
  sudo nomad "$@"
}

ENV=${ENV:-development}
nmdhelp='get|create|start|run|stop|rm'
nmdcmd=${1:-help}

case $nmdcmd in
start)
  config=${2:-""}
  if [[ -z $config ]]; then
    echo -e 'you must explicity disable or provide server config(s)'
    echo -e '\t syntax (dev mode): `start noconf`'
    echo -e '\t syntax: `start -config=X -config=Y ...`'
    exit 1
  fi
  if [[ $config =~ "noconf" ]]; then
    echo -e "starting server agent(s) in dev mode with sudo"
    nmd agent -dev -bind 0.0.0.0 -log-level INFO
  fi
  echo -e "starting server agent(s) with supplied config(s): ${@:2}"
  nmd agent "${@:2}"
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
    nmd job init -short "$3.nomad"
    echo -e "updating job name in $ENV.$name.nomad"
    sed -i "/job \"example\"/c\job \"$name\" {" "./$ENV.$name.nomad"
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
      echo -e "retrieving members of gossip ring"
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
    nmd job plan -var-file=.env.$ENV.compose.json "$ENV.$name.nomad"
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
*) echo -e $nmdhelp ;;
esac
