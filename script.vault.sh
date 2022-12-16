#!/usr/bin/env bash

set -eu

ADDR=${VAULT_ADDR:?-not set}
TOKEN=${VAULT_TOKEN:?-token not set}
TOKEN_HEADER="X-Vault-Token: $TOKEN"

curl_post() {
  curl -v -H "$TOKEN_HEADER" -X POST --data $1 $2
}

curl_put() {
  curl -v -H "$TOKEN_HEADER" -X PUT --data $1 $2
}

data_type_only() {
  data=$(
    jq -n -c \
      --arg type $2 \
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
enable-secret | enable-approle)
  data=$(data_type_only $@)
  url=$(
    [[ "$1" == *secret ]] &&
      echo 'v1/sys/mounts/secret' ||
      echo 'sys/auth/approle'
  )
  use_curl $data "$ADDR/$url"
  ;;
*)
  echo "$1 == enable-secret|enable-approle"
  ;;
esac
