#!/usr/bin/env bash

set -euo pipefail

# src === dir: src/* to dest/*
# src === file: file to dest/file
# 3rd param === anything: copy whatever $src is to dest/$src
# TODO: this should use rsync
cp_to_dir() {
  src=${1:?'source file or dir required'}
  dst=${2:?'destination directory required'}
  dir_to_dir=${3:-''}

  if ! test -d $dst; then
    echo_debug "creating destination dir: $dst"
    mkdir -p $dst
  fi

  if test -f $src || test -n "$dir_to_dir"; then
    echo_debug "copying $src to $dst"
    cp -fLR $src $dst
  elif test -d $src; then
    echo_debug "copying files in $src to $dst"
    cp -fLP -t $dst $src/*
  else
    echo_debug "source not a file or directory: $src"
  fi
}
