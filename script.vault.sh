#!/usr/bin/env bash

# @see https://curl.se/docs/manpage.html
# @see https://stedolan.github.io/jq/manual/
# @see https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2

set -eu

ADDR="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"
TOKEN_HEADER="X-Vault-Token: $TOKEN"

invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: see root/README.md for help"

  echo -e $INVALID_REQUEST_MSG
}

vault_curl() {
  curl -v --url $1 ${@:2}
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
vault_post_data_no_auth() {
  vault_curl $2 --data $1 -X POST
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
    echo -e "enabling secret engine: $3"

    data=$(data_type_only $3)
    url=$(
      [[ "$2" == secret ]] &&
        echo "sys/mounts/$2" ||
        echo "sys/auth/$2"
    )
    vault_post_data $data "$ADDR/$url" | jq
    ;;
  *) invalid_request ;;
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

    vault_post_data $data "$ADDR/auth/approle/role/$3" | jq
    ;;
  *) invalid_request ;;
  esac
  ;;
get)
  case $2 in
  postgres)
    case $3 in
    creds)
      echo -e "getting postgres creds for $4"

      ;;
    *) invalid_request ;;
    esac
    ;;
  secret)
    # eg: get secret secret/foo
    vault_curl_auth "$ADDR/secret/data/$3" | jq
    ;;
  status)
    # eg get status
    vault_curl "$ADDR/sys/health" | jq
    ;;
  creds)
    # eg get creds roleId secretId
    data=$(data_login $3 $4)
    echo "getting creds for $3 with $data"
    vault_post_data_no_auth $data "$ADDR/auth/approle/login" | jq
    ;;
  approle)
    case $3 in
    id)
      # eg: get approle id bff
      echo "getting id for approle $4"
      vault_curl_auth "$ADDR/auth/approle/role/$4/role-id" | jq
      ;;
    *) invalid_request ;;
    esac
    ;;
  *) invalid_request ;;
  esac
  ;;
help)
  vault_curl_auth "$ADDR/$2?help=1" | jq
  ;;
*) invalid_request ;;
esac
