#!/usr/bin/env bash

set -euo pipefail

get_filenames_in_dir_no_ext() {
  dirpath=${1:?'dir path is required'}

  declare -a filenames
  for file in $dirpath/*; do
    test -f $file || break

    local file_with_ext="${file##*/}"
    filenames+=("${file_with_ext%.*}")
  done

  echo "${filenames[@]}"
}
