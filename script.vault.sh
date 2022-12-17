#!/usr/bin/env bash

# not sure how far i'll be going with this script
# as i fixed the ssl issue on the vault server so i can use the cli again
# as well as finding the very small button in the top right corner
# of the vault UI that enables using the CLI from the browser ;)

set -eu

ADDR="${VAULT_ADDR:?-not set}/v1"
TOKEN=${VAULT_TOKEN:?-token not set}
TOKEN_HEADER="X-Vault-Token: $TOKEN"

vault_post() {
  curl -v -H "$TOKEN_HEADER" --data $1 $2
}

vault_post_no_data() {
  curl -v -H "$TOKEN_HEADER" $1
}

vault_put() {
  curl -v -H "$TOKEN_HEADER" -X PUT --data $1 $2
}

vault_get() {
  curl -v -H "$TOKEN_HEADER" $1
}

vault_list() {
  curl -v -H "$TOKEN_HEADER" -X LIST $1
}

data_type_only() {
  data=$(
    jq -n -c \
      --arg type $1 \
      '{ "type":$type }'
  )
  echo $data
}

data_policies_only() {
  data=$(
    jq -n -c \
      --arg policy $1 \
      '{ "policies":$policy }'
  )
  echo $data
}

case $1 in
enable)
  case $2 in
  secret | approle)
    # eg: enable secret kv-v2
    # eg: enable approle approle
    data=$(data_type_only $3)
    url=$(
      [[ "$2" == secret ]] &&
        echo "sys/mounts/$2" ||
        echo "sys/auth/$2"
    )
    echo "data is: $data"
    echo "url is: $url"
    vault_post $data "$ADDR/$url" | jq
    ;;
  esac
  ;;
secret)
  case $2 in
  get)
    # eg: secret get secret/foo
    vault_get "$ADDR/secret/data/$3" | jq
    ;;
  esac
  ;;
list-secrets) # doesnt work
  vault_list "$ADDR/secret/data/" | jq
  ;;
create)
  case $2 in
  approle-secret)
    # eg: create approle-secret bff
    echo "creating secret-id for approle $3"
    vault_post_no_data "$ADDR/auth/approle/role/$3/secret-id" | jq
    ;;
  approle)
    # eg: create approle someName role1,role2,role3
    data=$(data_policies_only $4)
    echo "creating approle $3 with policies $data"
    vault_post $data "$ADDR/auth/approle/role/$3"
    ;;
  esac
  ;;
get)
  case $2 in
  approle)
    case $3 in
    id)
      # eg: get approle id bff
      echo "getting id for approle $4"
      vault_get "$ADDR/auth/approle/role/$4/role-id" | jq
      ;;
    esac
    ;;
  esac
  ;;
help)
  vault_get "$ADDR/$2?help=1" | jq
  ;;
approle)
  case $2 in
  login)
    # eg: approle login roleId secretId
    echo "maching logging in with $roleId"
    # vault_post "$ADDR/v1/auth/approle/login"
    ;;
  esac
  ;;
*)
  echo "$1 == enable-secret|enable-approle"
  ;;
esac
