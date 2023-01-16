#!/bin/false

set -euo pipefail

get_file_name() {
  local some_path=${1:?'cant get unknown path: string not provided'}
  echo "${some_path##*/}"
}

get_filename_without_extension() {
  local full_path_with_ext=${1:?'cant get unknown path: string not provided'}
  local file_with_ext=$(get_file_name $full_path_with_ext)

  echo "${file_with_ext%.*}"
}
