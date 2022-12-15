#!/usr/bin/env bash

####
## set and retrieve dotenv-vault .env via current NODE_ENV value
## manage dotenv-vault lifecycle (push, pull, build, etc)
###

DOTENV_DEV='poop'
DOTENV_CI='poop'
DOTENV_STAGING='poop'
DOTENV_PROD='poop'

# ever time .env is updated you need to run build & push, i think both

create_env_source_me() {
  local file=".env.file"

  case $NODE_ENV in
  production)
    DOTENV_KEY=$DOTENV_PROD
    ;;
  staging)
    DOTENV_KEY=$DOTENV_STAGING
    ;;
  ci)
    DOTENV_KEY=$DOTENV_CI
    ;;
  *)
    NODE_ENV=development
    DOTENV_KEY=$DOTENV_DEV
    ;;
  esac

  echo "setting $file to $NODE_ENV"
  # echo "#!/bin/false" >$file
  echo "#!/usr/bin/env bash" >$file
  echo "NODE_ENV=\"$NODE_ENV\"" >>$file
  echo "DOTENV_KEY=\"$DOTENV_KEY\"" >>$file

  echo "$file updated"
  cat $file
}

case $1 in
push)
  echo "pushing .env"
  pnpx dotenv-vault push
  ;;
open)
  echo "opening vault"
  pnpx dotenv-vault open
  ;;
login)
  echo 'logging into vault'
  pnpx dotenv-vault login
  ;;
build)
  echo 'encrypting (build) .env.vault'
  pnpx dotenv-vault build
  ;;
keys)
  echo 'saving vault keys to ./.env.keys'
  pnpx dotenv-vault keys >.env.keys

  cat ./.env.keys
  ;;
*)
  echo '$1 = push|build|open|login|keys'
  echo 'check the docs: https://www.dotenv.org/docs'
  echo 'by default we create a sourcable .env file in .env.source.me'

  create_env_source_me
  ;;
esac
