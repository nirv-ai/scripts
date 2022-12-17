#!/usr/bin/env bash

# useful for:
## verifying endpoints before implementing in core
## interacting with vault without execing into a container or browser
## all cmds are something like: ./script.vault.sh do this thing with this data

# @see https://curl.se/docs/manpage.html
# @see https://stedolan.github.io/jq/manual/
# @see https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2

set -eu

ADDR="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"
TOKEN_HEADER="X-Vault-Token: $TOKEN"

vault_curl() {
  curl -v --url $1
}
vault_curl_auth() {
  vault_curl $1 -H "$TOKEN_HEADER"
}
vault_list() {
  vault_curl_auth $1 -X LIST
}
vault_post_data() {
  vault_curl_auth $2 --data $1
}
vault_put_data() {
  vault_curl_auth $2 -X PUT --data $1
}

data_type_only() {
  data=$(
    jq -n -c \
      --arg type $1 \
      '{ "type":$type }'
  )
  echo $data
}

data_login() {
  data=$(
    jq -n -c \
      --arg role_id $1 \
      --arg secret_id $2 \
      '{ "role_id": $role_id, "secret_id": $secret_id }'
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
    vault_post_data $data "$ADDR/$url" | jq
    ;;
  esac
  ;;
secret)
  case $2 in
  get)
    # eg: secret get secret/foo
    vault_curl_auth "$ADDR/secret/data/$3" | jq
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
    vault_curl_auth "$ADDR/auth/approle/role/$3/secret-id" -X POST | jq
    ;;
  approle)
    # eg: create approle someName role1,role2,role3
    data=$(data_policies_only $4)
    echo "creating approle $3 with policies $data"
    vault_post_data $data "$ADDR/auth/approle/role/$3"
    ;;
  esac
  ;;
get)
  case $2 in
  status)
    # eg get status
    vault_curl "$ADDR/sys/health" | jq
    ;;
  creds)
    # eg get creds roleId secretId
    data=$(data_login $3 $4)
    echo "getting creds for $3 with $data"
    vault_post_data $data "$ADDR/auth/approle/login" | jq
    ;;
  approle)
    case $3 in
    id)
      # eg: get approle id bff
      echo "getting id for approle $4"
      vault_curl_auth "$ADDR/auth/approle/role/$4/role-id" | jq
      ;;
    esac
    ;;
  esac
  ;;
help)
  vault_curl_auth "$ADDR/$2?help=1" | jq
  ;;
approle)
  case $2 in
  login)
    # eg: approle login roleId secretId
    echo "maching logging in with $roleId"
    # vault_post_data "$ADDR/v1/auth/approle/login"
    ;;
  esac
  ;;
*)
  echo "$1 == enable-secret|enable-approle"
  ;;
esac
