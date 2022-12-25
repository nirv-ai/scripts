#!/usr/bin/env bash

# append `--output-policy` to see the policy needed to execute a cmd

set -eu

# interface
ADDR="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"
DEBUG=${NIRV_SCRIPT_DEBUG:-''}

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
TOKEN_INFO_SELF=$AUTH_TOKEN/lookup-self
TOKEN_RENEW_ID=$AUTH_TOKEN/renew
TOKEN_RENEW_SELF=$AUTH_TOKEN/renew-self
TOKEN_RENEW_AXOR=$AUTH_TOKEN/renew-accessor
TOKEN_REVOKE_ID=$AUTH_TOKEN/revoke
TOKEN_REVOKE_SELF=$AUTH_TOKEN/revoke-self
TOKEN_REVOKE_AXOR=$AUTH_TOKEN/revoke-accessor
TOKEN_REVOKE_PARENT=$AUTH_TOKEN/revoke-orphan #children become orphans, parent secrets revoked
TOKEN_ROLES=$AUTH_TOKEN/roles                 # this/roleId [-X [DELETE | POST]] | this -X LIST
SECRET_DATA=secret/data
SYS_AUTH=sys/auth
SYS_HEALTH=sys/health
SYS_MOUNTS=sys/mounts
SYS_LEASES=sys/leases
SYS_LEASES_LOOKUP=$SYS_LEASES/lookup
SYS_LEASES_LOOKUP_DB_CREDS=$SYS_LEASES_LOOKUP/database/creds
SYS_POLY=sys/policies
SYS_POLY_ACL=$SYS_POLY/acl # -X PUT this/policyName
DB_CREDS=database/creds

######################## ERROR HANDLING
invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/vault/README.md"

  echo -e $INVALID_REQUEST_MSG
}
throw_if_file_doesnt_exist() {
  if test ! -f "$1"; then
    echo -e "file doesnt exist: $1"
    exit 1
  fi
}
get_payload_path() {
  local path=${1:?'cant get unknown path: string not provided'}

  throw_if_file_doesnt_exist $path

  # todo: if path starts with / return it
  # todo: if path starts with . throw
  # todo: if path doesnt end with .json throw

  echo "$(pwd)/$path"
}
get_payload_filename() {
  local full_path_with_ext=${1:?'cant get unknown path: string not provided'}
  local file_with_ext="${full_path_with_ext##*/}"

  echo "${file_with_ext%.*}" # file without extension
}

####################### REQUESTS
vault_curl() {
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.VAULT.SH\n------------'
    echo -e "[url]: $1\n[args]: ${@:2}\n------------\n\n"
  fi

  curl -v -H "Connection: close" --url $1 "${@:2}" | jq
}
vault_curl_auth() {
  vault_curl $1 -H "$TOKEN_HEADER" "${@:2}"
}
vault_list() {
  vault_curl "$1" -X LIST -H "$TOKEN_HEADER"
}
vault_post_no_data() {
  vault_curl "$1" -X POST -H "$TOKEN_HEADER"
}
vault_post_data_no_auth() {
  vault_curl $2 --data "$1"
}
vault_post_data() {
  vault_curl_auth $2 --data "$1"
}
vault_put_data() {
  vault_curl_auth $2 -X PUT --data "$1"
}
vault_patch_data() {
  vault_curl_auth $2 -X PATCH --data "$1"
}

#################### DATA
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
data_policy_only() {
  # @see https://gist.github.com/v6/f4683336eb1c4a6a98a0f3cf21e62df2
  local data=$(
    printf "{
    \"policy\": \""
    cat $1 | sed '/^[[:blank:]]*#/d;s/#.*//' | sed 's/\"/\\\"/g' | tr -d '\n' ##  Remove comments and serialize string
    printf "\"
}"
  )
  echo "$data"
}
data_policies_only() {
  # TODO: delete these and use data_policy_only
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
  axors)
    # @see https://github.com/hashicorp/vault/issues/1115 list only root tokens
    echo -e 'listing all tokens'
    vault_list $ADDR/$AUTH_TOKEN_ACCESSORS
    ;;
  secrets)
    vault_list "$ADDR/$SECRET_DATA/$3"
    ;;
  secret-engines)
    vault_curl_auth "$ADDR/$SYS_MOUNTS"
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

      echo -e "creating child token with payload:$payload_path"
      vault_post_data "@${payload_path}" $ADDR/$TOKEN_CREATE_CHILD
      ;;
    orphan) echo -e "TODO: creating orphan tokens not setup for payload" ;;
    *) echo -e $syntax ;;
    esac
    ;;
  poly)
    syntax='syntax: create poly path/to/distinct_poly_name.hcl'
    payload="${3:?$syntax}"
    payload_path=$(get_payload_path $payload)
    payload_data=$(data_policy_only $payload_path)
    payload_filename=$(get_payload_filename $payload_path)

    echo -e "creating policy $payload_filename:\n$(cat $payload_path)"
    vault_post_data "$payload_data" $ADDR/$SYS_POLY_ACL/$payload_filename
    ;;
  *) invalid_request ;;
  esac
  ;;
get)
  case $2 in
  token)
    getwhat=${3:-'syntax: get token [info|axor|self] ...'}
    id=${4:-''}

    case $getwhat in
    self)
      echo -e 'running credit check...'
      vault_curl_auth $ADDR/$TOKEN_INFO
      ;;
    info)
      if test -v $id; then
        echo -e 'syntax: get token info tokenId'
        exit 1
      fi

      data=$(data_token_only $id)
      echo -e "getting info for token: $data"
      vault_post_data $data $ADDR/$TOKEN_INFO
      ;;
    axor)
      if test -v $id; then
        echo -e 'syntax: get token axor accessorId'
        exit 1
      fi

      data=$(data_axor_only $id)
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
renew)
  who=${2:-''}
  tokenId=${3:-''}

  case $who in
  self)
    # ADDR/TOKEN_RENEW_SELF
    echo -e 'renewing self not setup'
    ;;
  id)
    # data_token_only $1 ADDR/TOKEN_RENEW_ID
    echo -e "renewing token ids not setup"
    ;;
  axor)
    # data_axor_only $1 ADDR/TOKEN_RENEW_AXOR
    echo -e "renewing token via accessors not setup"
    ;;
  esac
  ;;
revoke)
  revokewhat=${2-''}
  id=${3:-''}

  case $revokewhat in
  token)
    if test -v $id; then
      echo -e 'syntax: revoke token tokenId'
      exit 1
    fi

    data=$(data_token_only $id)
    echo -e "revoking token: $data"
    vault_post_data $data $ADDR/$TOKEN_REVOKE_ID
    ;;
  axor)
    if test -v $id; then
      echo -e 'syntax: revoke axor accessorId'
      exit 1
    fi

    data=$(data_axor_only $id)
    echo -e "revoking token via accessor: $data"
    vault_post_data $data $ADDR/$TOKEN_REVOKE_AXOR
    ;;
  parent)
    if test -v $id; then
      echo -e 'syntax: revoke parent tokenId'
      exit 1
    fi

    data=$(data_token_only $id)
    echo -e "revoking parent & parent secrets, orphaning children: $data"
    vault_post_data $data $ADDR/$TOKEN_REVOKE_PARENT
    ;;
  self)
    echo -e "good bye!"
    vault_post_no_data $ADDR/$TOKEN_REVOKE_SELF
    ;;
  esac
  ;;
rm)
  rmwhat=${2:-''}
  id=${3:-''}

  case $rmwhat in
  token-role)
    # -X auth/token/roles/$id
    echo -e 'delete token role not setup'
    ;;
  esac
  ;;
*) invalid_request ;;
esac
