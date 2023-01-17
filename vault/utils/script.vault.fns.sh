#!/bin/false
create_gpg_key() {
  data=$(gpg --full-generate-key)

  echo $data
}
save_gpg_key_asc() {
  # @see https://github.com/helm/helm/issues/2843
  # dont use --armor --export like github says, breaks vault
  gpg --export "$1" | base64 >$2
}
sync_vault_confs() {
  throw_missing_dir $VAULT_CONFIG_DIR 404 'configs not where expected'

  mkdir -p $VAULT_APP_DIR_CONFIG

  rsync -a --delete $VAULT_CONFIG_DIR/ $VAULT_APP_DIR_CONFIG
}
rm_app_data_dir() {
  request_sudo "wiping data from\n$VAULT_APP_DIR_DATA"
  sudo rm -rf $VAULT_APP_DIR_DATA/*
}
get_payload_path() {
  local path=${1:?'cant get unknown path: string not provided'}

  case $path in
  "/"*) echo $path ;;
  *) echo "$(pwd)/$path" ;; # this should point to the APP_CONF_DIR or something
  esac
}
get_single_unseal_token() {
  echo $(
    cat $JAIL_VAULT_UNSEAL_TOKENS |
      jq -r ".unseal_keys_b64[$1]" |
      base64 --decode |
      gpg -dq
  )
}
get_unseal_tokens() {
  throw_missing_file $JAIL_VAULT_UNSEAL_TOKENS 400 'unseal_token(s) not found'

  echo -e "VAULT_TOKEN:\n\n$VAULT_TOKEN\n"
  echo -e "UNSEAL_TOKEN(s):\n"
  unseal_threshold=$(cat $JAIL_VAULT_UNSEAL_TOKENS | jq '.unseal_threshold')
  i=0
  while [ $i -lt $unseal_threshold ]; do
    echo -e "\n$(get_single_unseal_token $i)"
    i=$((i + 1))
  done
}
unseal_vault() {
  throw_missing_program vault 400 'vault operator requires vault'

  unseal_threshold=$(cat $JAIL_VAULT_UNSEAL_TOKENS | jq '.unseal_threshold')
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

  throw_missing_file $payload_path 400 'policy file needed for create'

  payload_data=$(data_policy_only $payload_path)
  payload_filename=$(get_filename_without_extension $payload_path)

  echo_debug "creating policy $payload_filename:\n$(cat $payload_path)"
  vault_post_data "$payload_data" $VAULT_API/$SYS_POLY_ACL/$payload_filename
}
create_approle() {
  syntax='syntax: create_approle [/]path/to/distinct_role.json'
  payload="${1:?$syntax}"
  payload_path=$(get_payload_path $payload)

  throw_missing_file $payload_path 400 'app role file needed for create'

  payload_filename=$(get_filename_without_extension $payload_path)

  echo_debug "creating approle $payload_filename:\n$(cat $payload_path)"
  vault_post_data "@$payload_path" "$VAULT_API/$AUTH_APPROLE_ROLE/$payload_filename"
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
  vault_post_data $data "$VAULT_API/$URL"
}
