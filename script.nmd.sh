#!/usr/bin/env bash

# the UI is available at http://localhost:4646
# nomad doesnt work well with docker desktop, remove it

set -eu

nmd() {
  nomad "$@"
}

nmdhelp='get|create|team|start'
nmdcmd=${1:-help}

case $nmdcmd in
start)
  case $2 in
  dev)
    echo -e "starting agents in dev mode"
    nmd agent -dev -bind 0.0.0.0 -log-level INFO
    ;;
  *) echo -e "dev| ..." ;;
  esac
  ;;
create)
  case $2 in
  job)
    name=${3:-""}
    if [[ -z $name ]]; then
      echo 'syntax: `create job jobName`'
      exit 1
    fi

    echo -e "creating new job $3.nomad in the current dir"
    nmd job init -short "$3.nomad"
    echo -e "updating job name in $name.nomad"
    sed -i "/job \"example\"/c\job \"$name\" {" "./$name.nomad"
    ;;
  *) echo -e "job ..." ;;
  esac
  ;;
get)
  gethelp='get status|loc|loc-logs|plan'
  cmdname=${2:-""}
  if [[ -z $cmdname ]]; then
    echo -e $gethelp
    exit 1
  fi

  case $2 in
  status)
    cmdhelp='get status of what? node|all|job|team'
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
    job)
      name=${4:-""}
      if [[ -z $name ]]; then
        echo 'syntax: `get status job jobName`'
        exit 1
      fi
      echo -e "getting status of $name"
      nmd job status $name
      ;;
    *) echo -e "node|all|job" ;;
    esac
    ;;
  loc)
    id=${3:-""}
    if [[ -z $id ]]; then
      echo -e "syntax: get loc locId"
      exit 1
    fi
    echo -e "checking allocation for id $3"
    nmd alloc status $3
    ;;
  loc-logs)
    echo -e "fetching task $3 logs for allocation id $2 "
    nmd alloc logs $2 $3
    ;;
  plan)
    name=${3:-""}
    if [[ -z $name ]]; then
      echo 'syntax: `get plan jobName`'
      exit 1
    fi
    if test ! -f "$name.nomad"; then
      echo -e "ensure jobspec $name.nomad exists in current dir"
      echo -e 'create a new job plan with `create job jobName`'
      exit 1
    fi

    echo -e "creating job plan for $name"
    nmd job plan "$name.nomad"
    echo -e 'issues with get plan? make sure to `run job jobName` first'
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
  if test ! -f "$name.nomad"; then
    echo -e "ensure jobspec $name.nomad exists in current dir"
    echo -e 'create a new job with `create job jobName`'
    exit 1
  fi
  if [[ -z $index ]]; then
    echo -e 'you should always use the jobIndex'
    echo -e 'get the job index: `get plan jobName`'
    echo -e 'syntax: `run jobName [jobIndex]`'
    echo -e "running job $name anyway :("
    nmd job run $name.nomad
    exit $?
  fi
  echo -e "running job $name at index $index"
  nmd job run -check-index $index $name.nomad
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
