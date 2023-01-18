#!/usr/bin/env bash

# nim
alias nim_c='choosenim'
alias nimc_list='choosenim show'
alias nim_build='nimble build' # same as nimprodbuild
alias nim_debug_='nim c -r'
alias nim_dev_build='nim c --verbosity:2'
alias nim_dev_run='nim c -r --verbosity:0'
alias nim_i='nimble install'
alias nim_init='nimble init'
alias nim_list='nimble list'
alias nim_list_installed='nimble list --installed'
alias nim_prod_build='nim -d:release c --verbosity:2'
alias nim_prod_run='nim -d:release c -r --verbosity:0'
alias nim_refresh='nimble refresh'
