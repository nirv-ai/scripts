#!/usr/bin/env bash

# node ---------------------------------
alias npm_globals='npm list -g --depth=0'
alias nvm_alias_node='nvm alias default node'
alias nvm_defualt_system='nvm alias default system'
alias nvm_installed='nvm ls'
alias nvm_latest_install='nvm install node --reinstall-packages-from=default --latest-npm'
alias nvm_latest_lts='nvm ls-remote | grep -i latest'
alias nvm_latest_npm='nvm install-latest-npm'
alias nvm_stop='nvm deactivate' # only for current shell
