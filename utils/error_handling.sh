#!/usr/bin/env bash

set -euo pipefail

echo_err() {
  echo -e "$@" 1>&2
}
throw_missing_file() {
  filepath=${1:?'file path is required'}
  code=${2:?'error code is required'}
  help=${3:?'help text is required'}
  if test ! -f "$filepath"; then
    echo_err "\n[ERROR] file is required"
    echo_err "------------------------\n"
    echo_err "[STATUS] $code"
    echo_err "[REQUIRED FILE] $filepath"
    echo_err "[REQUIRED BY] $0"
    echo_err "[HELP] $help"
    echo_err "\n------------------------"
    exit 1
  fi
}
throw_missing_dir() {
  dirpath=${1:?'dir path is required'}
  code=${2:?'error code is required'}
  help=${3:?'help text is required'}
  if test ! -d "$dirpath"; then
    echo_err "\n[ERROR] directory is required"
    echo_err "------------------------\n"
    echo_err "[STATUS] $code"
    echo_err "[REQUIRED DIR] $dirpath"
    echo_err "[REQUIRED BY] $0"
    echo_err "[HELP] $help"
    echo_err "\n------------------------"
    exit 1
  fi
}
throw_missing_program() {
  program=${1:?'program name is required'}
  code=${2:?'error code is required'}
  help=${3:?'help text is required'}
  if ! type $1 2>&1 >/dev/null; then
    echo_err "\n[ERROR] executable $program is required and must exist in your path"
    echo_err "------------------------"
    echo_err "[STATUS] $code"
    echo_err "[REQUIRED BY] $0"
    echo_err "[HELP] $help"
    echo_err "\n------------------------"
    exit 1
  fi
}
