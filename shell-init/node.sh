#!/usr/bin/env bash

# nvm_ has like 10000 aliases, so we use node_ for everything
# node ---------------------------------
alias node_globals='npm list -g --depth=0'
alias node_alias_node='nvm alias default node'
alias node_defualt_system='nvm alias default system'
alias node_installed='nvm ls'
alias node_latest_install='nvm install node --reinstall-packages-from=default --latest-npm'
alias node_latest_lts='nvm ls-remote | grep -i latest'
alias node_latest_npm='nvm install-latest-npm'
alias node_stop='nvm deactivate' # only for current shell
