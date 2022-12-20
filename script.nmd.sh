#!/usr/bin/env bash

# you are required to be explicit with cmds in this file
# use `help` in response to unbound variable at a cmd path
set -eu

nmd() {
  nomad $@
}

case $1 in
status)
  case $2 in
  node) nmd node status ;;
  all) nmd status ;;
  help) echo -e "node|all" ;;
  esac
  ;;
help) echo -e "status | ..." ;;
esac

nmd_team() {
  if [ "$1" = "d" ]; then
    nmd server members -detailed
  else
    nmd server members
  fi
}

nmd_agent() {
  case $1 in
  dev)
    echo -e "starting dev mode"
    nomad agent -dev -bind 0.0.0.0 -log-level INFO
    ;;
  *) echo -e "dev | ..." ;;
  esac
}

# @see https://developer.hashicorp.com/nomad/tutorials/get-started/get-started-jobs
nmd_plan() {
  echo -e "creating job plan for $1"
  nmd job plan $1.nomad
}

nmd_job() {
  case $1 in
  init)
    if [[ -z $2 ]]; then
      echo '$2 === filename'
      return 1
    fi
    echo -e "creating new job $2.nomad in the current dir"
    nmd job init -short $2
    ;;
  run)
    # todo: check that file exists before running
    echo -e "running job $2"
    nmd job run ${2}.nomad
    ;;
  s)
    echo -e "status for job $2:"
    nmd job status $2
    ;;
  loc)
    echo -e "checking allocation for id $2"
    nmd alloc status $2
    ;;
  loc-logs)
    echo -e "fetching task $3 logs for allocation id $2 "
    nmd alloc logs $2 $3
    ;;
  *) echo -e 'init | run | s | loc | loc-logs ...' ;;
  esac
}
