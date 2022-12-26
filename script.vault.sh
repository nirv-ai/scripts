#!/usr/bin/env bash

# append `--output-policy` to see the policy needed to execute a cmd

set -euo pipefail

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
DB=database
DB_CONFIG=$DB/config             # LIST this, DELETE this/:name, POST this/:name {connection}
DB_CREDS=$DB/creds               # GET this/:name
DB_RESET=$DB/reset               # POST this/:name,
DB_ROLE=$DB/roles                # LIST this, GET this/:name, DELETE this/:name, POST this/:name {config},
DB_ROTATE=$DB/rotate-root        # POST this/:name ,
DB_STATIC_ROLE=$DB/static-roles  # LIST this, GET this/:name, DELETE this/:name, POST this/:name {config}
DB_STATIC_CREDS=$DB/static-creds # GET this/:name,
DB_STATIC_ROTATE=$DB/rotate-role # POST this/:name,
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

######################## ERROR HANDLING
invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/vault/README.md"

  echo -e $INVALID_REQUEST_MSG
}
throw_if_file_doesnt_exist() {
  # todo: if path starts with / return it
  # todo: if path starts with . throw

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
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.VAULT.SH\n------------'
    echo -e "[url]: $1\n[args]: ${@:2}\n------------\n\n"
  fi

  # curl -v should not be used outside of DEV
  curl -H "Connection: close" --url $1 "${@:2}" | jq
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
## -n=key-shares
## -t=key-threshold (# of key shares required to unseal)
init_vault() {
  echo -e 'this may take some time...'
  vault operator init \
    -format="json" \
    -n=2 \
    -t=2 \
    -root-token-pgp-key="$JAIL/root.asc" \
    -pgp-keys="$JAIL/root.asc,$JAIL/admin_vault.asc" >$JAIL/root.unseal.json
}
get_single_unseal_token() {
  echo $(
    cat $JAIL/root.unseal.json |
      jq -r ".unseal_keys_b64[$1]" |
      base64 --decode |
      gpg -dq
  )
}
get_unseal_tokens() {
  echo -e "VAULT_TOKEN:\n\n$VAULT_TOKEN\n"
  echo -e "UNSEAL_TOKEN(s):\n"
  unseal_threshold=$(cat $JAIL/root.unseal.json | jq '.unseal_threshold')
  i=0
  while [ $i -lt $unseal_threshold ]; do
    echo -e "\n$(get_single_unseal_token $i)"
    i=$((i + 1))
  done
}
unseal_vault() {
  unseal_threshold=$(cat $JAIL/root.unseal.json | jq '.unseal_threshold')
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

  echo -e "creating policy $payload_filename:\n$(cat $payload_path)"
  vault_post_data "$payload_data" $ADDR/$SYS_POLY_ACL/$payload_filename
}
create_approle() {
  syntax='syntax: create_approle [/]path/to/distinct_role.json'
  payload="${1:?$syntax}"
  payload_path=$(get_payload_path $payload)
  throw_if_file_doesnt_exist $payload_path
  payload_filename=$(get_filename_without_extension $payload_path)

  echo -e "creating approle $payload_filename:\n$(cat $payload_path)"
  vault_post_data "@$payload_path" "$ADDR/$AUTH_APPROLE_ROLE/$payload_filename"
}
enable_something() {
  # syntax: enable_something thisThing atThisPath
  # eg enable_something kv-v2 secret
  # eg enable_something approle approle
  # eg enable_something database database
  data=$(data_type_only $1)
  echo -e "enabling vault feature: $data at path $2"

  URL=$(
    [[ "$2" == secret || "$2" == database ]] &&
      echo "$SYS_MOUNTS/$2" ||
      echo "$SYS_AUTH/$2"
  )
  vault_post_data $data "$ADDR/$URL"
}
################################ workflows
process_policies_in_dir() {
  local policy_dir_full_path="$(pwd)/$1/*"
  echo -e "\nchecking for policies in: $policy_dir_full_path"

  for file_starts_with_policy_ in $policy_dir_full_path; do
    case $file_starts_with_policy_ in
    *"/policy_"*)
      echo -e "\nprocessing policy: $file_starts_with_policy_\n"
      create_policy $file_starts_with_policy_
      ;;
    esac
  done
}
process_auths_in_dir() {
  local auth_dir_full_path="$(pwd)/$1/*"
  echo -e "\nchecking for auth configs in: $auth_dir_full_path"

  for file_starts_with_auth_ in $auth_dir_full_path; do
    case $file_starts_with_auth_ in
    *"/auth_approle_role_"*)
      echo -e "\nprocessing approle auth config:\n$file_starts_with_auth_\n"
      create_approle $file_starts_with_auth_
      ;;
    esac
  done
}
enable_something_in_dir() {
  local enable_something_full_dir="$(pwd)/$1/*"
  echo -e "\nchecking for enable.thisthing.atthispath files in:\n$enable_something_full_dir\n"

  for file_starts_with_enable_X in $enable_something_full_dir; do
    case $file_starts_with_enable_X in
    *"/enable"*)
      local auth_filename=$(get_file_name $file_starts_with_enable_X)

      # configure shell to parse filename into expected components
      PREV_IFS="$IFS"       # save prev boundary
      IFS="."               # enable.thisThing.atThisPath
      set -f                # stop wildcard * expansion
      set -- $auth_filename # break filename @ '.' into positional args

      # reset shell back to normal
      set +f
      IFS=$PREV_IFS

      # make request if 2 and 3 are set, but 4 isnt
      if test -n ${2:-} && test -n ${3:-''} && test -z ${4:-''}; then
        enable_something $2 $3
      else
        echo -e "ignoring file\ndidnt match expectations: $auth_filename"
        echo -e 'filename syntax: ^enable.THING.AT_PATH$\n'
      fi
      ;;
    esac
  done
}

case $1 in
init) init_vault ;;
get_unseal_tokens) get_unseal_tokens ;;
unseal) unseal_vault ;;
enable)
  case $2 in
  kv-v2 | approle | database)
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
  approle-axors)
    vault_list "$ADDR/$AUTH_APPROLE_ROLE/${3:?'syntax: list approleName'}/secret-id"
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

    vault_post_no_data "$ADDR/$AUTH_APPROLE_ROLE/$3/secret-id" -X POST
    ;;
  approle)
    # eg: create approle [/]path/to/distinct_role_name.json
    payload_path=${3:?'syntax: create approle path/to/distinct_approle_name.json'}

    create_approle $payload_path
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
  approle-creds)
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
    secret-id)
      echo -e "looking up secret-id for approle $4"
      syntax='get approle secret-id roleName secretId'
      rolename=${4:?$syntax}
      secretid=${5:?$syntax}
      data=$(data_secret_id_only $secretid)

      vault_post_data "${data}" "$ADDR/$AUTH_APPROLE_ROLE/$rolename/secret-id/lookup"
      ;;
    secret-id-axor)
      echo -e "looking up secret-id accesor for approle $4"
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
  approle-secret-id)
    echo -e "revoking secret-id for approle $4"
    syntax='revoke approle-secret-id roleName secretId'
    rolename=${3:?$syntax}
    secretid=${4:?$syntax}
    data=$(data_secret_id_only $secretid)

    vault_post_data "${data}" "$ADDR/$AUTH_APPROLE_ROLE/$rolename/secret-id/destroy"
    ;;
  approle-secret-id-axor)
    echo -e "revoking secret-id accessor for approle $4"
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
  token-role)
    # -X DELETE? auth/token/roles/$id
    echo -e 'delete token role not setup'
    ;;
  approle-role) vault_delete "$ADDR/$AUTH_APPROLE_ROLE/${id:?'syntax: rm approle roleName'}" ;;
  esac
  ;;
process)
  processwhat=${2:-''}

  case $processwhat in
  policy_in_dir)
    dir=${3:?'syntax: process policy_in_dir path/to/dir'}
    throw_if_dir_doesnt_exist $dir
    process_policies_in_dir $dir
    ;;
  auth_in_dir)
    dir=${3:?'syntax: process auth_in_dir path/to/dir'}
    throw_if_dir_doesnt_exist $dir
    process_auths_in_dir $dir
    ;;
  enable_feature)
    dir=${3:?'syntax: process enable_feature path/to/dir'}
    throw_if_dir_doesnt_exist $dir
    enable_something_in_dir $dir
    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
