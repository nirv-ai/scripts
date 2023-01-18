#!/usr/bin/env bash

# vagrant, overriding vgt i'll never use it
alias vgt='vagrant'
alias vgt_destroy='vagrant destroy' # delete everything, but keep vagrantfile
alias vgt_list_boxes='vagrant box list'
alias vgt_list_snapshots='vagrant snapshot list'
alias vgt_provision='vagrant provision'
alias vgt_prune='vagrant global-status --prune'
alias vgt_reload='vagrant reload' # like restarting your comp
alias vgt_reload_provision='vagrant reload --provision'
alias vgt_restart='vagrant reload'
alias vgt_resume='vagrant resume' # like waking up your comp
alias vgt_running='vagrant status'
alias vgt_running_all='vagrant global-status'
alias vgt_ssh='vagrant ssh'
alias vgt_start='vagrant up'
alias vgt_start_and_provision='vagrant up --provision'
alias vgt_start_dont_provision='vagrant up --no-provision'
alias vgt_stop='vagrant halt'
alias vgt_suspend='vagrant suspend' # like hibernating your comp
