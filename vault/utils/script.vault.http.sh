#!/usr/bin/env bash

set -euo pipefail

######################## VAULT HTTP API
# append `--output-policy` to see the policy needed to execute a cmd

# headers
TOKEN_HEADER="X-Vault-Token: $VAULT_TOKEN"

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

vault_curl_auth() {
  curl_it $1 -H "$TOKEN_HEADER" "${@:2}"
}
vault_list() {
  curl_it "$1" -X LIST -H "$TOKEN_HEADER"
}
vault_post_no_data() {
  curl_it "$1" -X POST -H "$TOKEN_HEADER"
}
vault_delete() {
  curl_it "$1" -X DELETE -H "$TOKEN_HEADER"
}
vault_post_data_no_auth() {
  curl_it $2 --data "$1"
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

# DATA
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
  # TODO: fix this before before merging
  # ^ pretty sure a ticket is on the project board
  # ^ about posting .hcl files to vaults http api
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
