#!/usr/bin/env bash

set -eu

nmd() {
  nomad $@
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
team)
  echo -e "retrieving nomad server agents"
  nmd server members -detailed
  ;;
create)
  case $2 in
  job)
    jobname=${3:-""}
    if [[ -z $jobname ]]; then
      echo 'syntax: `create job jobName`'
      exit 1
    fi

    echo -e "creating new job $3.nomad in the current dir"
    nmd job init -short "$3.nomad"
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
    case $3 in
    node) nmd node status ;;
    all) nmd status ;;
    job) nmd job status $4 ;;
    *) echo -e "node|all|job" ;;
    esac
    ;;
  loc)
    echo -e "checking allocation for id $2"
    nmd alloc status $2
    ;;
  loc-logs)
    echo -e "fetching task $3 logs for allocation id $2 "
    nmd alloc logs $2 $3
    ;;
  plan)
    jobname=${3:-""}
    if [[ -z $jobname ]]; then
      echo 'syntax: `create plan jobName`'
      exit 1
    fi
    if test ! -f "$3.nomad"; then
      echo -e "ensure jobspec $3.nomad exists in current dir"
      echo -e 'create a new job plan with `create job jobName`'
      exit 1
    fi

    echo -e "creating job plan for $3"
    nmd job plan "$3.nomad"
    ;;
  *) echo -e $gethelp ;;
  esac
  ;;
run)
  jobname=${2:-""}
  if [[ -z $jobname ]]; then
    echo 'syntax: `run jobName`'
    exit 1
  fi
  if test ! -f "$2.nomad"; then
    echo -e "ensure jobspec $2.nomad exists in current dir"
    echo -e 'create a new job with `create job jobName`'
    exit 1
  fi
  echo -e "running job $2"
  nmd job run ${2}.nomad
  ;;
*) echo -e $nmdhelp ;;
esac
