#!/bin/false

## by using this file
## you help to enforce a common repo archicture across the entire platform
# scripts_parent_dir/repo_name/apps/app_prefix-appname/src/anything-goes

get_app_root() {
  local app_name=${1:?app name is required}

  local app_root="${APPS_DIR}/${APP_PREFIX}-$app_name"

  throw_missing_dir $app_root 400 'application directory doesnt exist'

  echo "$app_root"
}

get_app_dir() {
  local app_name=${1:?app name is required}
  local append_path=${2:?'path to append is required'}
  local mkdirp=${3:-''}

  local app_dir="$(get_app_root $app_name)/${append_path}"

  if test -n "$mkdirp"; then
    mkdir -p $app_dir
  fi

  echo "$app_dir"
}
