#!/usr/bin/env bash

# append `--output-policy` to see the policy needed to execute a cmd

set -eu

# interface
ADDR="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"

# vars
TOKEN_HEADER="X-Vault-Token: $TOKEN"

# endpoints
AUTH_APPROLE=auth/approle
AUTH_APPROLE_ROLE=$AUTH_APPROLE/role
AUTH_TOKEN=auth/token
AUTH_TOKEN_ACCESSORS=$AUTH_TOKEN/accessors
TOKEN_CREATE_CHILD=$AUTH_TOKEN/create
TOKEN_CREATE_ORPHAN=$AUTH_TOKEN/create-orphan
TOKEN_INFO=$AUTH_TOKEN/lookup
TOKEN_INFO_ACCESSOR=$AUTH_TOKEN/lookup-accessor
SECRET_DATA=secret/data
SYS_AUTH=sys/auth
SYS_HEALTH=sys/health
SYS_MOUNTS=sys/mounts
SYS_LEASES=sys/leases
SYS_LEASES_LOOKUP=$SYS_LEASES/lookup
SYS_LEASES_LOOKUP_DB_CREDS=$SYS_LEASES_LOOKUP/database/creds
DB_CREDS=database/creds

invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/vault/README.md"

  echo -e $INVALID_REQUEST_MSG
}
get_payload_path() {
  path=${1:?'cant get unknown path: string not provided'}

  # todo: if path starts with / return it
  # todo: if path starts with . throw
  # todo: if path doesnt end with .json throw

  echo "$(pwd)/$path"
}
vault_curl() {
  curl -v --url $1 "${@:2}" | jq
}
vault_curl_auth() {
  vault_curl $1 -H "$TOKEN_HEADER" "${@:2}"
}
vault_list() {
  vault_curl "$1" -X LIST -H "$TOKEN_HEADER"
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
vault_patch_data() {
  vault_curl_auth $2 -X PATCH --data "$1"
}
data_type_only() {
  local data=$(
    jq -n -c \
      --arg type $1 \
      '{ "type":$type }'
  )
  echo $data
}
data_token_only() {
  local data=$(
    jq -n -c \
      --arg tokenId $1 \
      '{ "token":$tokenId }'
  )
  echo $data
}
data_axor_only() {
  local data=$(
    jq -n -c \
      --arg axorId $1 \
      '{ "accessor":$axorId }'
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
    # eg enable secret kv-v2
    # eg enable approle approle
    # eg enable database database
    data=$(data_type_only $3)
    echo -e "enabling secret engine: $2 of $data"

    URL=$(
      [[ "$2" == secret || "$2" == database ]] &&
        echo "$SYS_MOUNTS/$2" ||
        echo "$SYS_AUTH/$2"
    )
    vault_post_data $data "$ADDR/$URL"
    ;;
  *) invalid_request ;;
  esac
  ;;
list)
  case $2 in
  tokens)
    # @see https://github.com/hashicorp/vault/issues/1115 list only root tokens
    echo -e 'listing all tokens'
    vault_list $ADDR/$AUTH_TOKEN_ACCESSORS
    ;;
  secrets)
    vault_list "$ADDR/$SECRET_DATA/$3"
    ;;
  secret-engines)
    vault_list "$ADDR/$SYS_MOUNTS"
    ;;
  approles)
    vault_list "$ADDR/$AUTH_APPROLE_ROLE"
    ;;
  postgres)
    case $3 in
    leases)
      # eg list postgres leases bff
      echo -e "listing provisioned leases for postgres role $4"

      vault_list "$ADDR/$SYS_LEASES_LOOKUP_DB_CREDS/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
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

      vault_post_data "$data" "$ADDR/$SECRET_DATA/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  approle-secret)
    # eg: create approle-secret bff
    echo -e "creating secret-id for approle $3"

    vault_curl_auth "$ADDR/$AUTH_APPROLE_ROLE/$3/secret-id" -X POST
    ;;
  approle)
    # eg: create approle someName role1,role2,role3
    data=$(data_policies_only $4)
    echo -e "upserting approle $3 with policies $data"

    vault_post_data $data "$ADDR/$AUTH_APPROLE_ROLE/$3"
    ;;
  token)
    syntax='syntax: create token [child|orphan] path/to/payload.json'
    tokentype=${3:-''}

    case $tokentype in
    child)
      payload="${4:?$syntax}"
      payload_path=$(get_payload_path $payload)
      if test ! -f "$payload_path"; then
        echo -e "payload json not found: $payload_path"
        exit 1
      fi

      echo -e "creating child token with payload: $payload_path"
      vault_post_data $payload_path $ADDR/$TOKEN_CREATE_CHILD
      ;;
    orphan) echo -e "TODO: creating orphan tokens not setup for payload" ;;
    *) echo -e $syntax ;;
    esac
    ;;
  *) invalid_request ;;
  esac
  ;;
get)
  case $2 in
  token)
    getwhat=${3:-'syntax: get token [info|axor] ...'}
    case $getwhat in
    info)
      tokenId=${4:-''}
      if test -v $tokenId; then
        echo -e 'syntax: get token info tokenId'
        exit 1
      fi

      data=$(data_token_only $tokenId)
      echo -e "getting info for token: $data"
      vault_post_data $data $ADDR/$TOKEN_INFO
      ;;
    axor)
      axorId=${4:-''}
      if test -v $axorId; then
        echo -e 'syntax: get token axor accessorId'
        exit 1
      fi

      data=$(data_axor_only $axorId)
      echo -e "getting info for token via accessor id: $data"
      vault_post_data $data $ADDR/$TOKEN_INFO_ACCESSOR
      ;;
    *) echo -e $getwhat ;;
    esac
    ;;
  postgres)
    case $3 in
    creds)
      echo -e "getting postgres creds for dbRole $4"
      vault_curl_auth "$ADDR/$DB_CREDS/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  secret)
    # eg: get secret secret/foo
    vault_curl_auth "$ADDR/$SECRET_DATA/$3"
    ;;
  status)
    # eg get status
    vault_curl "$ADDR/$SYS_HEALTH"
    ;;
  creds)
    # eg get creds roleId secretId
    data=$(data_login $3 $4)
    echo -e "getting creds for $3 with $data"

    vault_post_data_no_auth $data "$ADDR/$AUTH_APPROLE/login"
    ;;
  approle)
    case $3 in
    info)
      # eg get approle info bff
      echo -e "getting info for approle $4"

      vault_curl_auth "$ADDR/$AUTH_APPROLE_ROLE/$4"
      ;;
    id)
      # eg: get approle id bff
      echo -e "getting id for approle $4"

      vault_curl_auth "$ADDR/$AUTH_APPROLE_ROLE/$4/role-id"
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
