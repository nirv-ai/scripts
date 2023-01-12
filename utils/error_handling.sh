#!/usr/bin/env bash

set -euo pipefail

throw_missing_file() {
  filepath=${1:?'file path is required'}
  code=${2:?'error code is required'}
  help=${3:?'help text is required'}
  if test ! -f "$filepath"; then
    echo -e "\n[ERROR] file is required"
    echo -e "------------------------\n"
    echo -e "[STATUS] $code"
    echo -e "[REQUIRED FILE] $filepath"
    echo -e "[REQUIRED BY] $0"
    echo -e "[HELP] $help"
    echo -e "\n------------------------"
    exit 1
  fi
}
throw_missing_dir() {
  dirpath=${1:?'dir path is required'}
  code=${2:?'error code is required'}
  help=${3:?'help text is required'}
  if test ! -d "$dirpath"; then
    echo -e "\n[ERROR] directory is required"
    echo -e "------------------------\n"
    echo -e "[STATUS] $code"
    echo -e "[REQUIRED DIR] $dirpath"
    echo -e "[REQUIRED BY] $0"
    echo -e "[HELP] $help"
    echo -e "\n------------------------"
    exit 1
  fi
}
throw_missing_program() {
  program=${1:?'program name is required'}
  code=${2:?'error code is required'}
  help=${3:?'help text is required'}
  if ! type $1 2>&1 >/dev/null; then
    echo -e "\n[ERROR] executable $program is required and must exist in your path"
    echo -e "------------------------"
    echo -e "[STATUS] $code"
    echo -e "[REQUIRED BY] $0"
    echo -e "[HELP] $help"
    echo -e "\n------------------------"
    exit 1
  fi
}
