#!/usr/bin/env bash

# @see https://curl.se/docs/manpage.html
# @see https://stedolan.github.io/jq/manual/
# @see https://developer.hashicorp.com/vault/api-docs/secret/kv/kv-v2
# via the CLI you can append `--output-policy`
## to see the policy needed to execute a cmd

set -eu

ADDR="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"
TOKEN_HEADER="X-Vault-Token: $TOKEN"

invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: see root/README.md for help"

  echo -e $INVALID_REQUEST_MSG
}

vault_curl() {
  curl -v --url $1 "${@:2}" | jq
}
vault_curl_auth() {
  vault_curl $1 -H "$TOKEN_HEADER" "${@:2}"
}
vault_list() {
  vault_curl_auth $1 -X LIST
}
vault_list_get() {
  vault_curl_auth $1
}
vault_post_data() {
  vault_curl_auth $2 --data "$1"
}
vault_post_data_no_auth() {
  vault_curl $2 --data "$1"
}
vault_put_data() {
  vault_curl_auth $2 -X PUT --data "$1"
}

data_type_only() {
  local data=$(
    jq -n -c \
      --arg type $1 \
      '{ "type":$type }'
  )
  echo $data
}

data_login() {
  local data=$(
    jq -n -c \
      --arg role_id $1 \
      --arg secret_id $2 \
      '{ "role_id": $role_id, "secret_id": $secret_id }'
  )
  echo $data
}

data_policies_only() {
  local data=$(
    jq -n -c \
      --arg policy $1 \
      '{
        "token_policies": [ $policy ],
        "token_ttl": "24h",
        "token_max_ttl": "24h"
        }'
  )
  echo $data
}

case $1 in
enable)
  case $2 in
  secret | approle | database)
    # eg: enable secret kv-v2
    # eg: enable approle approle
    # eg enable database database
    data=$(data_type_only $3)
    echo -e "enabling secret engine: $2 of $data"

    URL=$(
      [[ "$2" == secret || "$2" == database ]] &&
        echo "sys/mounts/$2" ||
        echo "sys/auth/$2"
    )
    vault_post_data $data "$ADDR/$URL"
    ;;
  *) invalid_request ;;
  esac
  ;;
list)
  case $2 in
  secrets) # doesnt work
    vault_list "$ADDR/secret/data/$3"
    ;;
  secret-engines)
    vault_list_get "$ADDR/sys/mounts"
    ;;
  approles)
    vault_list "$ADDR/auth/approle/role"
    ;;
  *) invalid_request ;;
  esac
  ;;
create)
  case $2 in
  secret)
    case $3 in
    kv2)
      # eg create secret kv2 poo/in/ur/eye '{"a": "b", "c": "d"}'
      data="{\"data\": $5 }"
      echo -e "creating secret at $4 with $data"

      vault_post_data "$data" "$ADDR/secret/data/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  approle-secret)
    # eg: create approle-secret bff
    echo -e "creating secret-id for approle $3"

    vault_curl_auth "$ADDR/auth/approle/role/$3/secret-id" -X POST
    ;;
  approle)
    # eg: create approle someName role1,role2,role3
    data=$(data_policies_only $4)
    echo -e "upserting approle $3 with policies $data"

    vault_post_data $data "$ADDR/auth/approle/role/$3"
    ;;
  *) invalid_request ;;
  esac
  ;;
get)
  case $2 in
  postgres)
    case $3 in
    creds)
      echo -e "getting postgres creds for dbRole $4"
      vault_curl_auth "$ADDR/database/creds/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  secret)
    # eg: get secret secret/foo
    vault_curl_auth "$ADDR/secret/data/$3"
    ;;
  status)
    # eg get status
    vault_curl "$ADDR/sys/health"
    ;;
  creds)
    # eg get creds roleId secretId
    data=$(data_login $3 $4)
    echo -e "getting creds for $3 with $data"

    vault_post_data_no_auth $data "$ADDR/auth/approle/login"
    ;;
  approle)
    case $3 in
    info)
      # eg get approle info bff
      echo -e "getting info for approle $4"

      vault_curl_auth "$ADDR/auth/approle/role/$4"
      ;;
    id)
      # eg: get approle id bff
      echo -e "getting id for approle $4"

      vault_curl_auth "$ADDR/auth/approle/role/$4/role-id"
      ;;
    *) invalid_request ;;
    esac
    ;;
  *) invalid_request ;;
  esac
  ;;
help)
  vault_curl_auth "$ADDR/$2?help=1"
  ;;
*) invalid_request ;;
esac
