#!/usr/bin/env bash

set -euo pipefail

# src === dir: src/* to dest/*
# src === file: file to dest/file
# TODO: this should use rsync
cp_to_dir() {
  src=${1:?'source file or dir required'}
  dst=${2:?'destination directory required'}

  if ! test -d $dst; then
    echo_debug "creating destination dir: $dst"
    mkdir -p $dst
  fi

  if test -d $src; then
    echo_debug "copying files in $src to $dst"
    cp -fLP -t $dst $src/*
  elif test -f $src; then
    echo_debug "copying file $src to $dst"
    cp -fL $src $dst
  else
    echo_debug "source not a file or directory: $src"
  fi
}
