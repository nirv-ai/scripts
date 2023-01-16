#!/bin/false

use_nomad_fmt() {
  local conf_dir=${1:-$CONFIGS_DIR}

  throw_missing_program nomad 400 'nomad required to format hcl files'
  throw_missing_dir $conf_dir 400 'dir doesnt exist'

  echo_debug "formatting hcl in $conf_dir"

  nomad fmt -list=true -check -write=true -recursive $conf_dir
}
