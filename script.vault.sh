#!/usr/bin/env bash

# @see https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2

set -eu

ADDR="${VAULT_ADDR:?-not set}/v1"
TOKEN=${VAULT_TOKEN:?-token not set}
TOKEN_HEADER="X-Vault-Token: $TOKEN"

vault_post() {
  curl -v -H "$TOKEN_HEADER" --data $1 $2
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
      --arg policy $2 \
      '{ "policies":[$policy] }'
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
help)
  vault_get "$ADDR/$2?help=1" | jq
  ;;
*)
  echo "$1 == enable-secret|enable-approle"
  ;;
esac
