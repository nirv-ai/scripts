#!/bin/env bash

# virtualbox
alias vb='VBoxManage'
alias vb_ctrl='VBoxManage controlvm'
alias vb_ctrol_cmds='\vbctrl nameOfMachine pause|resume|reset|poweroff|savestate|etc'
alias vb_guest='VBoxManage guestcontrol'
alias vb_guest_cmds='VBoxManage guestcontrol --help' # execute cmds in guest from host cli, e.g. to run a program
alias vb_host_cmds='VBoxManage hostonlyif --help'
alias vb_list_all='VBoxManage list vms'
alias vb_running='VBoxManage list runningvms'
alias vb_start='VBoxManage startvm'
