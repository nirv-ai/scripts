#!/usr/bin/env bash

# append `--output-policy` to see the policy needed to execute a cmd

set -euo pipefail

# interface
ADDR="${VAULT_ADDR:?VAULT_ADDR not set: exiting}/v1"
TOKEN="${VAULT_TOKEN:?VAULT_TOKEN not set: exiting}"
DEBUG=${NIRV_SCRIPT_DEBUG:-''}
VAULT_INSTANCE_SRC_DIR="${VAULT_INSTANCE_SRC_DIR:-''}"
VAULT_INSTANCE_CONFIG_DIR="$VAULT_INSTANCE_SRC_DIR/config"
UNSEAL_TOKENS="${ROOT_TOKEN:-$JAIL/tokens/root/unseal_tokens.json}"
ROOT_PGP_KEY="${ROOT_PGP_KEY:-$JAIL/tokens/root/root.asc}"
ADMIN_PGP_KEY_DIR="${ADMIN_PGP_KEY_DIR:-$JAIL/tokens/admin}"
OTHER_TOKEN_DIR="${OTHER_TOKEN_DIR:-$JAIL/tokens/other}"

# vars
TOKEN_HEADER="X-Vault-Token: $TOKEN"

# VAULT FEATURE ENABLED PATHS
## modify the path at which a vault feature is enabled
## if you change these, you will need to change the config files
SECRET_KV1=env # [GET|LIST|DELETE] this/:path, POST this/:path {json}
SECRET_KV2=secret
DB_ENGINE=database
AUTH_APPROLE=auth/approle

# endpoints
AUTH_APPROLE_ROLE=$AUTH_APPROLE/role
AUTH_TOKEN=auth/token
AUTH_TOKEN_ACCESSORS=$AUTH_TOKEN/accessors
DB_CONFIG=$DB_ENGINE/config             # LIST this, DELETE this/:name, POST this/:name {connection}
DB_CREDS=$DB_ENGINE/creds               # GET this/:name
DB_RESET=$DB_ENGINE/reset               # POST this/:name,
DB_ROLES=$DB_ENGINE/roles               # LIST this, [GET|DELETE] this/:name, POST this/:name {config},
DB_ROTATE=$DB_ENGINE/rotate-root        # POST this/:name ,
DB_STATIC_ROLE=$DB_ENGINE/static-roles  # LIST this, [GET|DELETE] this/:name, POST this/:name {config}
DB_STATIC_CREDS=$DB_ENGINE/static-creds # GET this/:name,
DB_STATIC_ROTATE=$DB_ENGINE/rotate-role # POST this/:name,
TOKEN_CREATE_CHILD=$AUTH_TOKEN/create   # POST this/:rolename, POST this {config}
TOKEN_CREATE_ROLE=$AUTH_TOKEN/roles     # POST this/:rolename {config}
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
TOKEN_REVOKE_PARENT=$AUTH_TOKEN/revoke-orphan # children become orphans, parent secrets revoked
TOKEN_ROLES=$AUTH_TOKEN/roles                 # LIST this, [DELETE|POST] this/:roleId
SECRET_KV2_DATA=$SECRET_KV2/data              # GET this/:path?version=X, PATCH this/:path {json} -H Content-Type application/merge-patch+json, DELETE this/:path
SECRET_KV2_RM=$SECRET_KV2/delete              # POST this/:path {json}
SECRET_KV2_RM_UNDO=$SECRET_KV2/undelete       # POST this/:path {json}
SECRET_KV2_ERASE=$SECRET_KV2/destroy          # POST this:path {json}
SECRET_KV2_CONFIG=$SECRET_KV2/config          # GET this, POST this {config}
SECRET_KV2_SUBKEYS=$SECRET_KV2/subkeys        # GET this/:path?version=X&depth=Y
SECRET_KV2_KEYS=$SECRET_KV2/metadata          # [GET|LIST|DELETE] this/:path, POST this/:path {json}, PATCH this/:path {json} -H Content-Type application/merge-patch+json,
SYS_AUTH=sys/auth
SYS_HEALTH=sys/health
SYS_MOUNTS=sys/mounts
SYS_LEASES=sys/leases
SYS_LEASES_LOOKUP=$SYS_LEASES/lookup
SYS_LEASES_LOOKUP_DB_CREDS=$SYS_LEASES_LOOKUP/$DB_ENGINE/creds
SYS_POLY=sys/policies
SYS_POLY_ACL=$SYS_POLY/acl # PUT this/:polyName

######################## DEBUG ECHO
echo_debug() {
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.VAULT.SH\n------------'
    echo -e "$@"
    echo -e "------------\n\n"
  fi
}

######################## ERROR HANDLING
invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/vault/README.md"

  echo_debug $INVALID_REQUEST_MSG
}
throw_if_file_doesnt_exist() {
  if test ! -f "$1"; then
    echo -e "file doesnt exist: $1"
    exit 1
  fi
}
throw_if_dir_doesnt_exist() {
  if test ! -d "$1"; then
    echo -e "directory doesnt exist: $1"
    exit 1
  fi
}
get_payload_path() {
  local path=${1:?'cant get unknown path: string not provided'}

  case $path in
  "/"*) echo $path ;;
  *) echo "$(pwd)/$path" ;;
  esac
}
get_file_name() {
  local some_path=${1:?'cant get unknown path: string not provided'}
  echo "${some_path##*/}"
}
get_filename_without_extension() {
  local full_path_with_ext=${1:?'cant get unknown path: string not provided'}
  local file_with_ext=$(get_file_name $full_path_with_ext)

  # wont work if file.name.contains.periods
  # will return the `file` in above example
  echo "${file_with_ext%.*}"
}
####################### REQUESTS
vault_curl() {
  echo_debug "[url]: $1\n[args]: ${@:2}\n------------\n\n"

  curlargs = '-H "Connection: close"'
  if [ "$DEBUG" = 1 ]; then
    curlargs="$curlargs -v"
  else
    curlargs="$curlargs -s"
  fi
  # curl -v should not be used outside of DEV
  curl $curlargs --url $1 "${@:2}" | jq
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
vault_delete() {
  vault_curl "$1" -X DELETE -H "$TOKEN_HEADER"
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
  vault_curl_auth $2 -X PATCH -H Content-Type application/merge-patch+json --data "$1"
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
data_data_only() {
  echo "{ \"data\": $(cat $1 | jq)}"
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
data_secret_id_only() {
  local data=$(
    jq -n -c \
      --arg secret_id $1 \
      '{ "secret_id":$secret_id }'
  )
  echo $data
}
data_secret_id_axor_only() {
  local data=$(
    jq -n -c \
      --arg secret_id_axor $1 \
      '{ "secret_id_accessor":$secret_id_axor }'
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

#################### single use fns
## single executions
get_single_unseal_token() {
  echo $(
    cat $UNSEAL_TOKENS |
      jq -r ".unseal_keys_b64[$1]" |
      base64 --decode |
      gpg -dq
  )
}
get_unseal_tokens() {
  echo -e "VAULT_TOKEN:\n\n$VAULT_TOKEN\n"
  echo -e "UNSEAL_TOKEN(s):\n"
  unseal_threshold=$(cat $UNSEAL_TOKENS | jq '.unseal_threshold')
  i=0
  while [ $i -lt $unseal_threshold ]; do
    echo -e "\n$(get_single_unseal_token $i)"
    i=$((i + 1))
  done
}
unseal_vault() {
  unseal_threshold=$(cat $UNSEAL_TOKENS | jq '.unseal_threshold')
  i=0
  while [ $i -lt $unseal_threshold ]; do
    vault operator unseal $(get_single_unseal_token $i)
    i=$((i + 1))
  done
}
create_policy() {
  syntax='syntax: create_policy [/]path/to/distinct_poly_name.hcl'
  payload="${1:?$syntax}"
  payload_path=$(get_payload_path $payload)
  throw_if_file_doesnt_exist $payload_path
  payload_data=$(data_policy_only $payload_path)
  payload_filename=$(get_filename_without_extension $payload_path)

  echo_debug "creating policy $payload_filename:\n$(cat $payload_path)"
  vault_post_data "$payload_data" $ADDR/$SYS_POLY_ACL/$payload_filename
}
create_approle() {
  syntax='syntax: create_approle [/]path/to/distinct_role.json'
  payload="${1:?$syntax}"
  payload_path=$(get_payload_path $payload)
  throw_if_file_doesnt_exist $payload_path
  payload_filename=$(get_filename_without_extension $payload_path)

  echo_debug "creating approle $payload_filename:\n$(cat $payload_path)"
  vault_post_data "@$payload_path" "$ADDR/$AUTH_APPROLE_ROLE/$payload_filename"
}
enable_something() {
  # syntax: enable_something thisThing atThisPath
  # eg enable_something kv-v2 secret
  # eg enable_something approle approle
  # eg enable_something database database
  data=$(data_type_only $1)
  echo_debug "\n\nenabling vault feature: $data at path $2"

  case $1 in
  kv-v1 | kv-v2 | database)
    URL="$SYS_MOUNTS/$2"
    ;;
  approle)
    URL="$SYS_AUTH/$2"
    ;;
  *) invalid_request ;;
  esac
  vault_post_data $data "$ADDR/$URL"
}
################################ workflows
## TODO: we should NOT Be using the vault cli for anything in this file
init_vault() {
  local PGP_KEYS="$ROOT_PGP_KEY"

  throw_if_file_doesnt_exist $PGP_KEYS
  throw_if_dir_doesnt_exist $ADMIN_PGP_KEY_DIR

  local KEY_SHARES=1
  local THRESHOLD=${1:-2}

  for pgpkey_ends_with_asc in $ADMIN_PGP_KEY_DIR/*.asc; do
    PGP_KEYS="${PGP_KEYS},$pgpkey_ends_with_asc"
    KEY_SHARES=$((KEY_SHARES + 1))
  done

  if test $KEY_SHARES -lt $THRESHOLD; then
    echo "you need atleast $THRESHOLD tokens: $KEY_SHARES found"
    exit 1
  fi

  echo_debug 'this may take some time...'
  vault operator init \
    -format="json" \
    -n=$KEY_SHARES \
    -t=$THRESHOLD \
    -root-token-pgp-key="$ROOT_PGP_KEY" \
    -pgp-keys="$PGP_KEYS" >$JAIL/tokens/root/unseal_tokens.json
}

process_vault_admins_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  for policy in $VAULT_INSTANCE_CONFIG_DIR/*/vault-admin/policy_*.hcl; do
    throw_if_file_doesnt_exist $policy

    echo_debug "creating policy: $policy"
    create_policy $policy
  done

  for token_config in $VAULT_INSTANCE_CONFIG_DIR/*/vault-admin/token_*.json; do
    throw_if_file_doesnt_exist $token_config

    local token_name=$(get_file_name $token_config)
    echo_debug "creating admin token: $token_config"
    vault_post_data "@${token_config}" $ADDR/$TOKEN_CREATE_CHILD >$ADMIN_PGP_KEY_DIR/$token_name
  done
}

process_policies_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  for policy in $VAULT_INSTANCE_CONFIG_DIR/*/policy/policy_*.hcl; do
    test -f $policy || break

    echo_debug "creating policy: $policy"
    create_policy $policy
  done
}
process_engine_configs() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  for engine_config in $VAULT_INSTANCE_CONFIG_DIR/*/secret-engine/secret_*.json; do
    test -f $engine_config || break

    local engine_config_filename=$(get_file_name $engine_config)

    # configure shell to parse filename into expected components
    PREV_IFS="$IFS"                # save prev boundary
    IFS="."                        # secret_TYPE.TWO.THREE.FOUR.json
    set -f                         # stop wildcard * expansion
    set -- $engine_config_filename # break filename @ '.' into positional args

    # reset shell back to normal
    set +f
    IFS=$PREV_IFS

    engine_type=${1:-''}
    two=${2:-''}
    three=${3:-''}
    four=${4:-''}

    case $engine_type in
    secret_kv2)
      echo_debug "\n$engine_type\n[PATH]: $two\n[TYPE]: $three\n"

      case $3 in
      config)
        echo_debug "creating config for $engine_type enabled at path: $two"
        vault_post_data "@${engine_config}" "$ADDR/$two/$three"
        ;;
      *) echo_debug "ignoring unknown file format: $engine_config_filename" ;;
      esac
      ;;
    secret_database)
      echo_debug "\n$engine_type\n[NAME]: $two\n[CONFIG_TYPE]: $three\n"

      case $three in
      config)
        echo_debug "creating config for db: $two\n"
        vault_post_data "@${engine_config}" "$ADDR/$DB_CONFIG/$two"
        vault_post_no_data "$ADDR/$DB_ROTATE/$two"
        ;;

      role)
        echo_debug "creating role ${four} for db ${two}\n"
        vault_post_data "@${engine_config}" "$ADDR/$DB_ROLES/$four"
        ;;
      *) echo_debug "ignoring file with unknown format: $engine_config_filename" ;;
      esac
      ;;
    *) echo_debug "ignoring file with unknown format: $engine_config_filename" ;;
    esac
  done
}
process_token_role_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  for token_role in $VAULT_INSTANCE_CONFIG_DIR/*/token-role/token_role*.json; do
    test -f $token_role || break

    echo_debug "creating token_role: $token_role"

    local token_role_filename=$(get_file_name $token_role)

    # configure shell to parse filename into expected components
    PREV_IFS="$IFS"             # save prev boundary
    IFS="."                     # enable.thisThing.atThisPath
    set -f                      # stop wildcard * expansion
    set -- $token_role_filename # break filename @ '.' into positional args

    # reset shell back to normal
    set +f
    IFS=$PREV_IFS

    # make request if 2 is set, but 3 isnt
    if test -n ${2:-''} && test -n ${3:-''} && test -z ${4:-''}; then
      vault_post_data "@${token_role}" "$ADDR/$TOKEN_CREATE_ROLE/${2}"
    else
      echo_debug "ignoring file\ndidnt match expectations: $token_role_filename"
      echo_debug 'filename syntax: ^token_role.ROLE_NAME$\n'
    fi
  done
}
process_tokens_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR
  mkdir -p $OTHER_TOKEN_DIR

  for token_config in $VAULT_INSTANCE_CONFIG_DIR/*/token/token_create*; do
    test -f $token_config || break

    local token_create_filename=$(get_file_name $token_config)

    # configure shell to parse filename into expected components
    PREV_IFS="$IFS"               # save prev boundary
    IFS="."                       # secret_TYPE.TWO.THREE.FOUR.json
    set -f                        # stop wildcard * expansion
    set -- $token_create_filename # break filename @ '.' into positional args

    # reset shell back to normal
    set +f
    IFS=$PREV_IFS

    auth_scheme=${1:-''}
    token_type=${2:-''}
    token_name=${3:-''}
    ROLE_ID_FILE="${OTHER_TOKEN_DIR}/${token_type}.id.json"
    CREDENTIAL_FILE="${OTHER_TOKEN_DIR}/${token_type}.${token_name}.json"

    case $auth_scheme in
    token_create_approle)
      echo_debug "\n$auth_scheme\n\n[ROLE_ID_FILE]: $ROLE_ID_FILE\n[SECRET_ID_FILE]: $CREDENTIAL_FILE\n"

      # save role-id
      vault_curl_auth "$ADDR/$AUTH_APPROLE_ROLE/$token_type/role-id" >$ROLE_ID_FILE

      # save new secret-id for authenticating as role-id
      vault_post_no_data "$ADDR/$AUTH_APPROLE_ROLE/$token_type/secret-id" -X POST >$CREDENTIAL_FILE
      ;;
    token_create_token_role)
      echo_debug "\n$auth_scheme\n\n[TOKEN_FILE]: $CREDENTIAL_FILE\n"

      # save new token for authenticating as token_role
      vault_post_no_data $ADDR/$TOKEN_CREATE_CHILD/$token_type >$CREDENTIAL_FILE
      ;;
    *) echo_debug "ignoring file with unknown format: $token_config" ;;
    esac
  done
}
process_auths_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  # keeping case syntax as we'll likely integrate with more auth schemes
  for auth_config in $VAULT_INSTANCE_CONFIG_DIR/*/auth/*.json; do
    test -f $auth_config || break

    case $auth_config in
    *"/auth_approle_role_"*)
      echo_debug "\nprocessing approle auth config:\n$auth_config\n"
      create_approle $auth_config
      ;;
    esac
  done
}
enable_something_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  for feature in $VAULT_INSTANCE_CONFIG_DIR/*/enable-feature/enable*; do
    test -f $feature || break

    echo_debug "enabling feature: $feature"
    local feature_name=$(get_file_name $feature)

    # configure shell to parse filename into expected components
    PREV_IFS="$IFS"      # save prev boundary
    IFS="."              # enable.thisThing.atThisPath
    set -f               # stop wildcard * expansion
    set -- $feature_name # break filename @ '.' into positional args

    # reset shell back to normal
    set +f
    IFS=$PREV_IFS

    # make request if 2 and 3 are set, but 4 isnt
    if test -n ${2:-} && test -n ${3:-''} && test -z ${4:-''}; then
      enable_something $2 $3
    else
      echo_debug "ignoring file\ndidnt match expectations: $feature"
      echo_debug 'filename syntax: ^enable.THING.AT_PATH$\n'
    fi
  done
}
process_secret_data_in_dir() {
  throw_if_dir_doesnt_exist $VAULT_INSTANCE_CONFIG_DIR

  for secret_data in $VAULT_INSTANCE_CONFIG_DIR/*/secret-data/hydrate_*.json; do
    test -f $secret_data || break

    local data_hydrate_filename=$(get_file_name $secret_data)

    # configure shell to parse filename into expected components
    PREV_IFS="$IFS"               # save prev boundary
    IFS="."                       # hydrate_ENGINE_TYPE.ENGINE_PATH.SECRET_PATH.json
    set -f                        # stop wildcard * expansion
    set -- $data_hydrate_filename # break filename @ '.' into positional a rgs

    # reset shell back to normal
    set +f
    IFS=$PREV_IFS

    engine_type=${1:-''}
    engine_path=${2:-''}
    secret_path=${3:-''}

    case $engine_type in
    'hydrate_kv1')
      echo_debug "\n$engine_type\n\n[ENGINE_PATH]: $engine_path\n[SECRET_PATH]: $secret_path\n"

      vault_post_data "@${secret_data}" "$ADDR/$SECRET_KV1/$secret_path"

      ;;
    'hydrate_kv2')
      echo_debug "\n$engine_type\n\n[ENGINE_PATH]: $engine_path\n[SECRET_PATH]: $secret_path\n"
      payload_data=$(data_data_only $secret_data)
      vault_post_data "${payload_data}" "$ADDR/$SECRET_KV2_DATA/$secret_path" >/dev/null
      ;;
    *) echo_debug "ignoring file with unknown format: $secret_data" ;;
    esac
  done
}

###################### CMDS
case $1 in
init) init_vault ${2:-2} ;;
get_unseal_tokens) get_unseal_tokens ;;
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
    vault_list $ADDR/$AUTH_TOKEN_ACCESSORS
    ;;
  secret-keys)
    syntax='syntax: list secret-keys kv[1|2] secretPath'
    secret_path=${4:-''}
    case $3 in
    kv1) vault_list "$ADDR/$SECRET_KV1/$secret_path" ;;
    kv2) vault_list "$ADDR/$SECRET_KV2_KEYS/$secret_path" ;;
    esac
    ;;
  secret-engines)
    vault_curl_auth "$ADDR/$SYS_MOUNTS"
    ;;
  approles)
    vault_list "$ADDR/$AUTH_APPROLE_ROLE"
    ;;
  approle-axors)
    vault_list "$ADDR/$AUTH_APPROLE_ROLE/${3:?'syntax: list approleName'}/secret-id"
    ;;
  postgres)
    case $3 in
    leases)
      # eg list postgres leases bff
      echo_debug "listing provisioned leases for postgres role $4"

      vault_list "$ADDR/$SYS_LEASES_LOOKUP_DB_CREDS/$4"
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
      throw_if_file_doesnt_exist $payload_path
      payload_data=$(data_data_only $payload_path)
      echo_debug "patching secret at $secret_path with $payload_data"

      vault_patch_data "${payload_data}" "$ADDR/$SECRET_KV2_DATA/$secret_path"
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
      throw_if_file_doesnt_exist $payload_path
      payload_data=$(data_data_only $payload_path)
      echo_debug "creating secret at $secret_path with $payload_data"

      vault_post_data "${payload_data}" "$ADDR/$SECRET_KV2_DATA/$secret_path"
      ;;
    kv1)
      syntax='syntax: create secret kv1 secretPath pathToJson'
      secret_path=${4:?$syntax}
      payload=${5:?$syntax}
      payload_path=$(get_payload_path $payload)
      throw_if_file_doesnt_exist $payload_path
      echo_debug "creating secret at $secret_path with $payload_path"

      vault_post_data "@${payload_path}" "$ADDR/$SECRET_KV1/$secret_path"
      ;;
    *) invalid_request ;;
    esac
    ;;
  approle-secret)
    # eg: create approle-secret bff
    echo_debug "creating secret-id for approle $3"

    vault_post_no_data "$ADDR/$AUTH_APPROLE_ROLE/$3/secret-id" -X POST
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
      vault_post_no_data $ADDR/$TOKEN_CREATE_CHILD/$rolename
      ;;
    child)
      payload="${4:?$syntax}"
      payload_path=$(get_payload_path $payload)

      echo_debug "creating child token with payload:$payload_path"
      vault_post_data "@${payload_path}" $ADDR/$TOKEN_CREATE_CHILD
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
      vault_curl_auth $ADDR/$TOKEN_INFO_SELF
      ;;
    info)
      if test -v $id; then
        echo_debug 'syntax: get token info tokenId'
        exit 1
      fi

      data=$(data_token_only $id)
      echo_debug "getting info for token: $data"
      vault_post_data $data $ADDR/$TOKEN_INFO
      ;;
    axor)
      if test -v $id; then
        echo_debug 'syntax: get token axor accessorId'
        exit 1
      fi

      data=$(data_axor_only $id)
      echo_debug "getting info for token via accessor id: $data"
      vault_post_data $data $ADDR/$TOKEN_INFO_ACCESSOR
      ;;
    *) echo_debug $getwhat ;;
    esac
    ;;
  postgres)
    case $3 in
    creds)
      echo_debug "getting postgres creds for dbRole $4"
      vault_curl_auth "$ADDR/$DB_CREDS/$4"
      ;;
    *) invalid_request ;;
    esac
    ;;
  secret-kv2-config) vault_curl_auth "$ADDR/$SECRET_KV2_CONFIG" ;;
  secret)
    secret_path=${4:?'syntax: get secret kv[1|2] secretPath'}
    case $3 in
    kv2)
      version=${5:-''}
      vault_curl_auth "$ADDR/$SECRET_KV2_DATA/$secret_path?version=$version"
      ;;
    kv1) vault_curl_auth "$ADDR/$SECRET_KV1/$secret_path" ;;
    *) invalid_request ;;
    esac
    ;;
  status)
    # eg get status
    vault_curl "$ADDR/$SYS_HEALTH"
    ;;
  approle-creds)
    # eg get creds roleId secretId
    data=$(data_login $3 $4)
    echo_debug "getting creds for $3 with $data"

    vault_post_data_no_auth $data "$ADDR/$AUTH_APPROLE/login"
    ;;
  approle)
    case $3 in
    info)
      # eg get approle info bff
      echo_debug "getting info for approle $4"

      vault_curl_auth "$ADDR/$AUTH_APPROLE_ROLE/$4"
      ;;
    id)
      # eg: get approle id bff
      echo_debug "getting id for approle $4"

      vault_curl_auth "$ADDR/$AUTH_APPROLE_ROLE/$4/role-id"
      ;;
    secret-id)
      echo_debug "looking up secret-id for approle $4"
      syntax='get approle secret-id roleName secretId'
      rolename=${4:?$syntax}
      secretid=${5:?$syntax}
      data=$(data_secret_id_only $secretid)

      vault_post_data "${data}" "$ADDR/$AUTH_APPROLE_ROLE/$rolename/secret-id/lookup"
      ;;
    secret-id-axor)
      echo_debug "looking up secret-id accesor for approle $4"
      syntax='get approle secret-id-axor roleName secretIdAccessor'
      rolename=${4:?$syntax}
      secretid=${5:?$syntax}
      data=$(data_secret_id_axor_only $secretid)

      vault_post_data "${data}" "$ADDR/$AUTH_APPROLE_ROLE/$rolename/secret-id-accessor/lookup"
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
    vault_post_data $data $ADDR/$TOKEN_REVOKE_ID
    ;;
  axor)
    if test -v $id; then
      echo_debug 'syntax: revoke axor accessorId'
      exit 1
    fi

    data=$(data_axor_only $id)
    echo_debug "revoking token via accessor: $data"
    vault_post_data $data $ADDR/$TOKEN_REVOKE_AXOR
    ;;
  parent)
    if test -v $id; then
      echo_debug 'syntax: revoke parent tokenId'
      exit 1
    fi

    data=$(data_token_only $id)
    echo_debug "revoking parent & parent secrets, orphaning children: $data"
    vault_post_data $data $ADDR/$TOKEN_REVOKE_PARENT
    ;;
  self)
    echo_debug "good bye!"
    vault_post_no_data $ADDR/$TOKEN_REVOKE_SELF
    ;;
  approle-secret-id)
    echo_debug "revoking secret-id for approle $4"
    syntax='revoke approle-secret-id roleName secretId'
    rolename=${3:?$syntax}
    secretid=${4:?$syntax}
    data=$(data_secret_id_only $secretid)

    vault_post_data "${data}" "$ADDR/$AUTH_APPROLE_ROLE/$rolename/secret-id/destroy"
    ;;
  approle-secret-id-axor)
    echo_debug "revoking secret-id accessor for approle $4"
    syntax='revoke approle-secret-id-axor roleName secretIdAccessor'
    rolename=${3:?$syntax}
    secretidAxor=${4:?$syntax}
    data=$(data_secret_id_axor_only $secretidAxor)

    vault_post_data "${data}" "$ADDR/$AUTH_APPROLE_ROLE/$rolename/secret-id-accessor/destroy"
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
    kv2) vault_curl_auth "$ADDR/$SECRET_KV2/$secret_path" -X DELETE ;;
    kv1) vault_curl_auth "$ADDR/$SECRET_KV1/$secret_path" -X DELETE ;;
    *) invalid_request ;;
    esac
    ;;
  token-role)
    # -X DELETE? $AUTH/token/roles/$id
    echo_debug 'delete token role not setup'
    ;;
  approle-role) vault_delete "$ADDR/$AUTH_APPROLE_ROLE/${id:?'syntax: rm approle roleName'}" ;;
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
