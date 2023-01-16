#!/usr/bin/env bash

set -euo pipefail

######################## SETUP
DOCS_URI='url for your readme file'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# PLATFORM UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## INTERFACE
# group by increasing order of dependency

JAIL_VAULT_ADMIN="${JAIL_VAULT_PGP_DIR:-${JAIL}/tokens/admin}"
JAIL_VAULT_OTHER="${OTHER_TOKEN_DIR:-${JAIL}/tokens/other}"
JAIL_VAULT_ROOT="${JAIL_VAULT_ROOT:-${JAIL}/tokens/root}"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"
VAULT_API="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
VAULT_APP_SRC_PATH='src/vault'
VAULT_SERVER_APP_NAME='core-vault'

JAIL_VAULT_ROOT_PGP_KEY="${JAIL_VAULT_ROOT}/root.asc"
JAIL_VAULT_UNSEAL_TOKENS="${JAIL_VAULT_ROOT}/unseal_tokens.json"
VAULT_APP_CONFIG_DIR="$(get_app_dir $VAULT_SERVER_APP_NAME $VAULT_APP_SRC_PATH/config)"

VAULT_APP_TARGET="${VAULT_APP_CONFIG_DIR}/${VAULT_APP_TARGET:-''}"

# VAULT FEATURE PATHS
# TODO any changes require config updates
SECRET_KV1=env # [GET|LIST|DELETE] this/:path, POST this/:path {json}
SECRET_KV2=secret
DB_ENGINE=database
AUTH_APPROLE=auth/approle

source $SCRIPTS_DIR/vault/script.vault.http.sh

declare -A EFFECTIVE_INTERFACE=(
  [AUTH_APPROLE]=$AUTH_APPROLE
  [DB_ENGINE]=$DB_ENGINE
  [DOCS_URI]=$DOCS_URI
  [JAIL_VAULT_ADMIN]=$JAIL_VAULT_ADMIN
  [JAIL_VAULT_OTHER]=$JAIL_VAULT_OTHER
  [JAIL_VAULT_ROOT]=$JAIL_VAULT_ROOT
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  [SECRET_KV1]=$SECRET_KV1
  [SECRET_KV2]=$SECRET_KV2
  [VAULT_API]=$VAULT_API
  [VAULT_APP_CONFIG_DIR]=$VAULT_APP_CONFIG_DIR
  [VAULT_APP_TARGET]=$VAULT_APP_TARGET
)

######################## CREDIT CHECK
echo_debug_interface

throw_missing_dir $JAIL_VAULT_ADMIN 400 'vault admin dir not found'
throw_missing_dir $JAIL_VAULT_OTHER 400 'vault other token dir not found'
throw_missing_dir $JAIL_VAULT_ROOT 400 'vault root admin dir not found'
throw_missing_dir $SCRIPT_DIR_PARENT 500 "somethings wrong: cant find myself in filesystem"
400 'app files are put here'

throw_missing_program curl 400 '@see https://curl.se/download.html'
throw_missing_program jq 400 '@see https://stedolan.github.io/jq/'

######################## FNS
# VAULT UTILS
for util in $SCRIPTS_DIR/vault/utils/*.sh; do
  source $util
done

exit 1
######################## EXECUTE
cmd=${1:-''}
case $cmd in
init) init_vault ${2:-2} ;;
get_JAIL_VAULT_UNSEAL_TOKENS) get_JAIL_VAULT_UNSEAL_TOKENS ;;
get_single_unseal_token)
  token_index=${2-0}
  echo -e "\n----\n\n$(get_single_unseal_token $token_index)\n\n----\n"
  ;;
unseal) unseal_vault ;;
enable)
  case $2 in
  kv-v2 | kv-v1 | approle | database)
    syntax='syntax: enable thisEngine atThisPath'
    engine=${2:?$syntax}
    atpath=${3:?$syntax}
    enable_something $engine $atpath
    ;;
  *) invalid_request ;;
  esac
  ;;
list)
  case $2 in
  # @see https://github.com/hashicorp/vault/issues/1115 list only root tokens
  axors)
    echo_debug 'listing all tokens'
    vault_list $VAULT_API/$AUTH_TOKEN_ACCESSORS
    ;;
  secret-keys)
    syntax='syntax: list secret-keys kv[1|2] secretPath'
    secret_path=${4:-''}
    case $3 in
    kv1) vault_list "$VAULT_API/$SECRET_KV1/$secret_path" ;;
    kv2) vault_list "$VAULT_API/$SECRET_KV2_KEYS/$secret_path" ;;
    esac
    ;;
  secret-engines)
    vault_curl_auth "$VAULT_API/$SYS_MOUNTS"
    ;;
  approles)
    vault_list "$VAULT_API/$AUTH_APPROLE_ROLE"
    ;;
  approle-axors)
    vault_list "$VAULT_API/$AUTH_APPROLE_ROLE/${3:?'syntax: list approleName'}/secret-id"
    ;;
  postgres)
    case $3 in
    leases)
      # eg list postgres leases bff
      echo_debug "listing provisioned leases for postgres role $4"

      vault_list "$VAULT_API/$SYS_LEASES_LOOKUP_DB_CREDS/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  *) invalid_request ;;
  esac
  ;;
patch)
  case $2 in
  secret)
    case $3 in
    kv2)
      syntax='syntax: patch secret kv2 secretPath pathToJson'
      secret_path=${4:?$syntax}
      payload=${5:?$syntax}
      payload_path=$(get_payload_path $payload)

      throw_missing_file $payload_path 400 'json data file not found'

      payload_data=$(data_data_only $payload_path)

      echo_debug "patching secret at $secret_path with $payload_data"
      vault_patch_data "${payload_data}" "$VAULT_API/$SECRET_KV2_DATA/$secret_path"
      ;;
    esac
    ;;
  esac
  ;;
create)
  case $2 in
  secret)
    case $3 in
    kv2)
      syntax='syntax: create secret kv2 secretPath pathToJson'
      secret_path=${4:?$syntax}
      payload=${5:?$syntax}
      payload_path=$(get_payload_path $payload)

      throw_missing_file $payload_path 400 'json data file not found'

      payload_data=$(data_data_only $payload_path)
      echo_debug "creating secret at $secret_path with $payload_data"

      vault_post_data "${payload_data}" "$VAULT_API/$SECRET_KV2_DATA/$secret_path"
      ;;
    kv1)
      syntax='syntax: create secret kv1 secretPath pathToJson'
      secret_path=${4:?$syntax}
      payload=${5:?$syntax}
      payload_path=$(get_payload_path $payload)

      throw_missing_file $payload_path 400 'json data file not found'

      echo_debug "creating secret at $secret_path with $payload_path"

      vault_post_data "@${payload_path}" "$VAULT_API/$SECRET_KV1/$secret_path"
      ;;
    *) invalid_request ;;
    esac
    ;;
  approle-secret)
    # eg: create approle-secret bff
    echo_debug "creating secret-id for approle $3"

    vault_post_no_data "$VAULT_API/$AUTH_APPROLE_ROLE/$3/secret-id" -X POST
    ;;
  approle)
    # eg: create approle [/]path/to/distinct_role_name.json
    payload_path=${3:?'syntax: create approle path/to/distinct_approle_name.json'}

    create_approle $payload_path
    ;;
  token)
    syntax='syntax: create token [child|orphan] path/to/payload.json | for-role roleName'
    tokentype=${3:-''}

    case $tokentype in
    for-role)
      rolename="${4:?'syntax: create token for-role roleName'}"

      echo_debug "creating token for role: $rolename"
      vault_post_no_data $VAULT_API/$TOKEN_CREATE_CHILD/$rolename
      ;;
    child)
      payload="${4:?$syntax}"
      payload_path=$(get_payload_path $payload)

      echo_debug "creating child token with payload:$payload_path"
      vault_post_data "@${payload_path}" $VAULT_API/$TOKEN_CREATE_CHILD
      ;;
    orphan) echo_debug "TODO: creating orphan tokens not setup for payload" ;;
    *) echo_debug $syntax ;;
    esac
    ;;
  poly)
    syntax='syntax: create poly path/to/distinct_poly_name.hcl'
    policy_path=${3:?$syntax}
    create_policy $policy_path
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
      echo_debug 'running credit check...'
      vault_curl_auth $VAULT_API/$TOKEN_INFO_SELF
      ;;
    info)
      if test -v $id; then
        echo_debug 'syntax: get token info tokenId'
        exit 1
      fi

      data=$(data_token_only $id)
      echo_debug "getting info for token: $data"
      vault_post_data $data $VAULT_API/$TOKEN_INFO
      ;;
    axor)
      if test -v $id; then
        echo_debug 'syntax: get token axor accessorId'
        exit 1
      fi

      data=$(data_axor_only $id)
      echo_debug "getting info for token via accessor id: $data"
      vault_post_data $data $VAULT_API/$TOKEN_INFO_ACCESSOR
      ;;
    *) echo_debug $getwhat ;;
    esac
    ;;
  postgres)
    case $3 in
    creds)
      echo_debug "getting postgres creds for dbRole $4"
      vault_curl_auth "$VAULT_API/$DB_CREDS/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  secret-kv2-config) vault_curl_auth "$VAULT_API/$SECRET_KV2_CONFIG" ;;
  secret)
    secret_path=${4:?'syntax: get secret kv[1|2] secretPath'}
    case $3 in
    kv2)
      version=${5:-''}
      vault_curl_auth "$VAULT_API/$SECRET_KV2_DATA/$secret_path?version=$version"
      ;;
    kv1) vault_curl_auth "$VAULT_API/$SECRET_KV1/$secret_path" ;;
    *) invalid_request ;;
    esac
    ;;
  status)
    # eg get status
    curl_it "$VAULT_API/$SYS_HEALTH"
    ;;
  approle-creds)
    # eg get creds roleId secretId
    data=$(data_login $3 $4)
    echo_debug "getting creds for $3 with $data"

    vault_post_data_no_auth $data "$VAULT_API/$AUTH_APPROLE/login"
    ;;
  approle)
    case $3 in
    info)
      # eg get approle info bff
      echo_debug "getting info for approle $4"

      vault_curl_auth "$VAULT_API/$AUTH_APPROLE_ROLE/$4"
      ;;
    id)
      # eg: get approle id bff
      echo_debug "getting id for approle $4"

      vault_curl_auth "$VAULT_API/$AUTH_APPROLE_ROLE/$4/role-id"
      ;;
    secret-id)
      echo_debug "looking up secret-id for approle $4"
      syntax='get approle secret-id roleName secretId'
      rolename=${4:?$syntax}
      secretid=${5:?$syntax}
      data=$(data_secret_id_only $secretid)

      vault_post_data "${data}" "$VAULT_API/$AUTH_APPROLE_ROLE/$rolename/secret-id/lookup"
      ;;
    secret-id-axor)
      echo_debug "looking up secret-id accesor for approle $4"
      syntax='get approle secret-id-axor roleName secretIdAccessor'
      rolename=${4:?$syntax}
      secretid=${5:?$syntax}
      data=$(data_secret_id_axor_only $secretid)

      vault_post_data "${data}" "$VAULT_API/$AUTH_APPROLE_ROLE/$rolename/secret-id-accessor/lookup"
      ;;
    *) invalid_request ;;
    esac
    ;;
  *) invalid_request ;;
  esac
  ;;
help)
  vault_curl_auth "$VAULT_API/$2?help=1"
  ;;
renew)
  who=${2:-''}
  tokenId=${3:-''}

  case $who in
  self)
    # ADDR/TOKEN_RENEW_SELF
    echo_debug 'renewing self not setup'
    ;;
  id)
    # data_token_only $1 ADDR/TOKEN_RENEW_ID
    echo_debug "renewing token ids not setup"
    ;;
  axor)
    # data_axor_only $1 ADDR/TOKEN_RENEW_AXOR
    echo_debug "renewing token via accessors not setup"
    ;;
  esac
  ;;
revoke)
  revokewhat=${2-''}
  id=${3:-''}

  case $revokewhat in
  token)
    if test -v $id; then
      echo_debug 'syntax: revoke token tokenId'
      exit 1
    fi

    data=$(data_token_only $id)
    echo_debug "revoking token: $data"
    vault_post_data $data $VAULT_API/$TOKEN_REVOKE_ID
    ;;
  axor)
    if test -v $id; then
      echo_debug 'syntax: revoke axor accessorId'
      exit 1
    fi

    data=$(data_axor_only $id)
    echo_debug "revoking token via accessor: $data"
    vault_post_data $data $VAULT_API/$TOKEN_REVOKE_AXOR
    ;;
  parent)
    if test -v $id; then
      echo_debug 'syntax: revoke parent tokenId'
      exit 1
    fi

    data=$(data_token_only $id)
    echo_debug "revoking parent & parent secrets, orphaning children: $data"
    vault_post_data $data $VAULT_API/$TOKEN_REVOKE_PARENT
    ;;
  self)
    echo_debug "good bye!"
    vault_post_no_data $VAULT_API/$TOKEN_REVOKE_SELF
    ;;
  approle-secret-id)
    echo_debug "revoking secret-id for approle $4"
    syntax='revoke approle-secret-id roleName secretId'
    rolename=${3:?$syntax}
    secretid=${4:?$syntax}
    data=$(data_secret_id_only $secretid)

    vault_post_data "${data}" "$VAULT_API/$AUTH_APPROLE_ROLE/$rolename/secret-id/destroy"
    ;;
  approle-secret-id-axor)
    echo_debug "revoking secret-id accessor for approle $4"
    syntax='revoke approle-secret-id-axor roleName secretIdAccessor'
    rolename=${3:?$syntax}
    secretidAxor=${4:?$syntax}
    data=$(data_secret_id_axor_only $secretidAxor)

    vault_post_data "${data}" "$VAULT_API/$AUTH_APPROLE_ROLE/$rolename/secret-id-accessor/destroy"
    ;;
  *) invalid_request ;;
  esac
  ;;
rm)
  rmwhat=${2:-''}
  id=${3:-''}

  case $rmwhat in
  secret)
    secret_path=${4:?'syntax: get secret kv[1|2] secretPath'}
    case $3 in
    kv2) vault_curl_auth "$VAULT_API/$SECRET_KV2/$secret_path" -X DELETE ;;
    kv1) vault_curl_auth "$VAULT_API/$SECRET_KV1/$secret_path" -X DELETE ;;
    *) invalid_request ;;
    esac
    ;;
  token-role)
    # -X DELETE? $AUTH/token/roles/$id
    echo_debug 'delete token role not setup'
    ;;
  approle-role) vault_delete "$VAULT_API/$AUTH_APPROLE_ROLE/${id:?'syntax: rm approle roleName'}" ;;
  esac
  ;;
process)
  processwhat=${2:-''}

  case $processwhat in
  # this is the init order
  vault_admin) process_vault_admins_in_dir ;;
  policy) process_policies_in_dir ;;
  token_role) process_token_role_in_dir ;;
  enable_feature) enable_something_in_dir ;;
  auth) process_auths_in_dir ;;
  secret_engine) process_engine_configs ;;
  token) process_tokens_in_dir ;;
  secret_data) process_secret_data_in_dir ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
