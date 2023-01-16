#!/bin/false

# pipelines
init_vault() {
  local PGP_KEYS="$JAIL_VAULT_ROOT_PGP_KEY"
  local KEY_SHARES=1
  local THRESHOLD=${1:-2}

  throw_missing_file $PGP_KEYS 400 'the root pgp key is required to init vault'

  for pgpkey_ends_with_asc in $JAIL_VAULT_ADMIN/*.asc; do
    PGP_KEYS="${PGP_KEYS},$pgpkey_ends_with_asc"
    KEY_SHARES=$((KEY_SHARES + 1))
  done

  if test $KEY_SHARES -lt $THRESHOLD; then
    echo_err "you need atleast $THRESHOLD tokens: $KEY_SHARES found"
    exit 1
  fi

  throw_missing_program vault 400 'vault operator requires vault'

  echo_debug 'this may take some time...'
  vault operator init \
    -format="json" \
    -n=$KEY_SHARES \
    -t=$THRESHOLD \
    -root-token-pgp-key="$JAIL_VAULT_ROOT_PGP_KEY" \
    -pgp-keys="$PGP_KEYS" >$JAIL/tokens/root/$JAIL_VAULT_UNSEAL_TOKENS.json
}

should_process() {
  local file_path=${1:-''}

  case $(test -n "$VAULT_APP_TARGET" && echo $?) in
  0)
    case $file_path in
    $VAULT_APP_TARGET*) return 0 ;;
    *) return 1 ;;
    esac
    ;;
  esac

  return 0
}
process_vault_admins_in_dir() {
  for policy in $VAULT_APP_CONFIG_DIR/*/vault-admin/policy_*.hcl; do
    test -f $policy || break
    if ! should_process $policy; then continue; fi

    echo_debug "creating policy: $policy"
    create_policy $policy
  done

  for token_config in $VAULT_APP_CONFIG_DIR/*/vault-admin/token_*.json; do
    test -f $token_config || break
    if ! should_process $token_config; then continue; fi

    local token_name=$(get_file_name $token_config)
    echo_debug "creating admin token: $token_config"
    vault_post_data "@${token_config}" $VAULT_ADDR/$TOKEN_CREATE_CHILD >$JAIL_VAULT_ADMIN/$token_name
  done
}

process_policies_in_dir() {
  for policy in $VAULT_APP_CONFIG_DIR/*/policy/policy_*.hcl; do
    test -f $policy || break
    if ! should_process $policy; then continue; fi

    echo_debug "creating policy: $policy"
    create_policy $policy
  done
}
process_engine_configs() {
  for engine_config in $VAULT_APP_CONFIG_DIR/*/secret-engine/secret_*.json; do
    test -f $engine_config || break
    if ! should_process $engine_config; then continue; fi

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
        vault_post_data "@${engine_config}" "$VAULT_ADDR/$two/$three"
        ;;
      *) echo_debug "ignoring unknown file format: $engine_config_filename" ;;
      esac
      ;;
    secret_database)
      echo_debug "\n$engine_type\n[NAME]: $two\n[CONFIG_TYPE]: $three\n"

      case $three in
      config)
        echo_debug "creating config for db: $two\n"
        vault_post_data "@${engine_config}" "$VAULT_ADDR/$DB_CONFIG/$two"
        vault_post_no_data "$VAULT_ADDR/$DB_ROTATE/$two"
        ;;

      role)
        echo_debug "creating role ${four} for db ${two}\n"
        vault_post_data "@${engine_config}" "$VAULT_ADDR/$DB_ROLES/$four"
        ;;
      *) echo_debug "ignoring file with unknown format: $engine_config_filename" ;;
      esac
      ;;
    *) echo_debug "ignoring file with unknown format: $engine_config_filename" ;;
    esac
  done
}
process_token_role_in_dir() {

  for token_role in $VAULT_APP_CONFIG_DIR/*/token-role/token_role*.json; do
    test -f $token_role || break
    if ! should_process $token_role; then continue; fi

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
      vault_post_data "@${token_role}" "$VAULT_ADDR/$TOKEN_CREATE_ROLE/${2}"
    else
      echo_debug "ignoring file\ndidnt match expectations: $token_role_filename"
      echo_debug 'filename syntax: ^token_role.ROLE_NAME$\n'
    fi
  done
}
process_tokens_in_dir() {

  mkdir -p $OTHER_TOKEN_DIR

  for token_config in $VAULT_APP_CONFIG_DIR/*/token/token_create*; do
    test -f $token_config || break
    if ! should_process $token_config; then continue; fi

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
      vault_curl_auth "$VAULT_ADDR/$AUTH_APPROLE_ROLE/$token_type/role-id" >$ROLE_ID_FILE

      # save new secret-id for authenticating as role-id
      vault_post_no_data "$VAULT_ADDR/$AUTH_APPROLE_ROLE/$token_type/secret-id" -X POST >$CREDENTIAL_FILE
      ;;
    token_create_token_role)
      echo_debug "\n$auth_scheme\n\n[TOKEN_FILE]: $CREDENTIAL_FILE\n"

      # save new token for authenticating as token_role
      vault_post_no_data $VAULT_ADDR/$TOKEN_CREATE_CHILD/$token_type >$CREDENTIAL_FILE
      ;;
    *) echo_debug "ignoring file with unknown format: $token_config" ;;
    esac
  done
}
process_auths_in_dir() {

  # keeping case syntax as we'll likely integrate with more auth schemes
  for auth_config in $VAULT_APP_CONFIG_DIR/*/auth/*.json; do
    test -f $auth_config || break
    if ! should_process $auth_config; then continue; fi

    case $auth_config in
    *"/auth_approle_role_"*)
      echo_debug "\nprocessing approle auth config:\n$auth_config\n"
      create_approle $auth_config
      ;;
    esac
  done
}
enable_something_in_dir() {

  for feature in $VAULT_APP_CONFIG_DIR/*/enable-feature/enable*; do
    test -f $feature || break
    if ! should_process $feature; then continue; fi

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

  for secret_data in $VAULT_APP_CONFIG_DIR/*/secret-data/hydrate_*.json; do
    test -f $secret_data || break
    if ! should_process $secret_data; then continue; fi

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

      vault_post_data "@${secret_data}" "$VAULT_ADDR/$SECRET_KV1/$secret_path"

      ;;
    'hydrate_kv2')
      echo_debug "\n$engine_type\n\n[ENGINE_PATH]: $engine_path\n[SECRET_PATH]: $secret_path\n"
      payload_data=$(data_data_only $secret_data)
      vault_post_data "${payload_data}" "$VAULT_ADDR/$SECRET_KV2_DATA/$secret_path" >/dev/null
      ;;
    *) echo_debug "ignoring file with unknown format: $secret_data" ;;
    esac
  done
}
