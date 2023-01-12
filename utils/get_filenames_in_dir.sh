#!/usr/bin/env bash

set -euo pipefail

get_filenames_in_dir() {
  dirpath=${1:?'dir path is required'}

  declare -a filenames
  for file in $dirpath/*; do
    test -f $file || break

    filenames+=("${file##*/}")
  done

  echo "${filenames[@]}"
}
