#!/usr/bin/env bash

npack() {
  nomad-pack "$@"
}
npack_reg_add() {
  if test -z $1 || test -z $2; then
    echo -e '$1 = registry_alias\n$2 = registry_url'

    return 1
  fi

  npack registry add $1 $2
}
npack_list() {
  npack registry list
}
npack_deployed() {
  npack status
}
npack_deploy() {
  if test -z $1; then
    echo -e '$1 = pack name\n[$2 = registry_alias]'

    return 1
  fi

  local run_args="run $1"

  if test -n "$2"; then
    run_args="$run_args --registry=$2"
  fi

  npack $run_args
}
npack_info_deployed() {
  if test -z $1; then
    echo '$1 = pack name'

    return 1
  fi

  npack status $1
}
npack_info() {
  if test -z $1; then
    echo '$1 = pack name'

    return 1
  fi

  npack info $1
}

npack_destroy_deployed() {
  if test -z $1; then
    echo '$1 = pack name'

    return 1
  fi

  npack destroy $1
}
