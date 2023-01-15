#!/usr/bin/env bash

set -euo pipefail

cp_to_dir() {
  src=${1:?'source file or dir required'}
  dst=${2:?'destination directory required'}

  if ! test -d $dst; then
    echo_debug "creating destination dir: $dst"
    mkdir -p $dst
  fi

  if test -d $src; then
    cp -fLP -t $dst $src/*
  elif test -f $src; then
    cp -fL $src $dst
  else
    echo_debug "source not a file or directory: $src"
  fi
}
