#!/bin/false

use_hashi_fmt() {
  local conf_dir=${1:-$CONFIGS_DIR}
  local formatter=${2:-''}
  throw_missing_dir $conf_dir 400 'dir doesnt exist'

  echo_info "recursively formatting hashicorp confs in $conf_dir"

  # use -check so errors are logged
  # but use || true so it doesnt stop execution of pipelines
  local lint_args="fmt -check -list=true -write=true -recursive $conf_dir"

  if test -n "$formatter"; then
    $formatter $lint_args || true
  elif type terraform &>/dev/null; then
    terraform $lint_args || true
    echo_debug 'using terraform fmt'
  elif type nomad &>/dev/null; then
    echo_debug 'using nomad fmt'
    nomad $lint_args || true
  else
    echo_err 400 'either terraform or nomad is required to lint hashicorp hcl files'
    exit 1
  fi
}
