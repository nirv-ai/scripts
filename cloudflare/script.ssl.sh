#!/usr/bin/env bash

######
## @see https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#node-certificates
## @see https://github.com/cloudflare/cfssl/wiki/Creating-a-new-CSR
######

set -euo pipefail

######################## SETUP
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/cfssl/README.md'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## INTERFACE
# grouped by increasing order of dependency
CA_CN="${CA_CN:-mesh.nirv.ai}"
CA_PEM_NAME="${CA_PEM_NAME:-ca}"
CFSSL_CONFIG_NAME="${CFSSL_CONFIG_NAME:-cfssl.json}"
CLI_NAME="${CLI_NAME:-cli}"
CLIENT_NAME="${CLIENT_NAME:-client}"
SERVER_NAME="${SERVER_NAME:-server}"

JAIL_DIR_TLS="${JAIL_DIR_TLS:-$JAIL/$CA_CN/tls}"

CA_CERT="${CA_CERT:-$JAIL_DIR_TLS/$CA_PEM_NAME}.pem"
CA_PRIVKEY="${CA_PRIVKEY:-$JAIL_DIR_TLS/$CA_PEM_NAME}-key.pem"

declare -A EFFECTIVE_INTERFACE=(
  [CA_CERT]=$CA_CERT
  [CA_CN]=$CA_CN
  [CA_PEM_NAME]=$CA_PEM_NAME
  [CA_PRIVKEY]=$CA_PRIVKEY
  [CFSSL_CONFIG_NAME]=$CFSSL_CONFIG_NAME
  [CFSSL_DIR]=$CFSSL_DIR
  [CLI_NAME]=$CLI_NAME
  [CLIENT_NAME]=$CLIENT_NAME
  [JAIL_DIR_TLS]=$JAIL_DIR_TLS
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  [SCRIPTS_DIR]=$SCRIPTS_DIR
  [SERVER_NAME]=$SERVER_NAME
)

######################## CREDIT CHECK
echo_debug_interface

throw_missing_program cfssl 404 'sudo apt install golang-cfssl'
throw_missing_program cfssljson 404 'sudo apt install golang-cfssl'
throw_missing_program jq 404 'sudo apt install jq'

throw_missing_dir $CFSSL_DIR 404 'cant find cfssl configuration files'
throw_missing_dir $JAIL 404 "mkdir -p $JAIL"

######################## FNS
## reusable
create_tls_dir() {
  mkdir -p ${1:-JAIL_DIR_TLS}
}
chmod_cert_files() {
  declare pub_perm=0644
  declare prv_perm=0640
  request_sudo "setting permissions on new TLS certs\n[FILES]$JAIL_DIR_TLS/*.pem \n\n[$pub_perm] *.pem\n[$prv_perm] *-key.pem"

  sudo chmod $pub_perm $JAIL_DIR_TLS/*.pem
  sudo chmod $prv_perm $JAIL_DIR_TLS/*key.pem
}
get_cfssl_config() {
  local use_cfssl_config=${1:-$CFSSL_CONFIG_NAME}
  local use_cn_config_dir=${2:-CFSSL_DIR}

  if test -f "${use_cn_config_dir}/${use_cfssl_config}"; then
    echo "${use_cn_config_dir}/${use_cfssl_config}"
    return 0
  else
    # go up 1 directory
    # just incase they didnt follow instructions
    # and put the cfssl.json in the cfssl dir instead of the CA_CN dir
    # lol i did this like 3 times like wtf
    next_cn_config_dir=$(dirname $use_cn_config_dir)
    if test -f "${next_cn_config_dir}/${use_cfssl_config}"; then
      echo "${next_cn_config_dir}/${use_cfssl_config}"
      return 0
    else
      # use the hardcoded configs/cfssl.json and throw if missing
      default_cfssl_config="${CFSSL_DIR}/cfssl.json"

      if test ! -f $default_cfssl_config; then
        # throw the original request
        throw_missing_file "${use_cn_config_dir}/${use_cfssl_config}" 404 "cfssl configuration required"
      fi

      echo "$default_cfssl_config"
      return 0
    fi
  fi
}

## actions
create_root_ca() {
  local use_ca_cn="${1:-$CA_CN}"
  local CA_CONFIG_DIR="${CFSSL_DIR}/${use_ca_cn}"

  local CA_CONFIG_FILE="${CA_CONFIG_DIR}/csr.root.ca.json"
  throw_missing_file $CA_CONFIG_FILE 404 "root ca configuration file"

  echo_debug "creating rootca with config: $(cat $CA_CONFIG_FILE | jq)"

  local this_jail_tls_dir="${JAIL}/${use_ca_cn}/tls"
  create_tls_dir $this_jail_tls_dir

  local ca_file="$this_jail_tls_dir/${2:-$CA_PEM_NAME}"
  if test -f "$ca_file.pem"; then
    echo_debug "file already_exists:\n$ca_file"
  else
    cfssl genkey -initca $CA_CONFIG_FILE | cfssljson -bare "$ca_file"
  fi

  chmod_cert_files
}
create_server_cert() {
  local total=${1:-1}
  local use_ca_cn=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local SERVER_NAME=${4:-$SERVER_NAME}
  local use_cfssl_config_name=${5:-$CFSSL_CONFIG_NAME}

  local this_jail_tls_dir="${JAIL}/${use_ca_cn}/tls"
  local CA_CERT="${this_jail_tls_dir}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${this_jail_tls_dir}/${CA_PEM_NAME}-key.pem"
  create_tls_dir $this_jail_tls_dir

  local CN_CONFIG_DIR="${CFSSL_DIR}/${use_ca_cn}"
  local SERVER_CONFIG="${CN_CONFIG_DIR}/csr.server.${SERVER_NAME}.json"
  throw_missing_file $SERVER_CONFIG 404 'couldnt find server csr config'

  local use_cfssl_config="$(get_cfssl_config $use_cfssl_config_name $CN_CONFIG_DIR)"

  echo_debug "creating $total server certificates"

  declare -i i=0
  while [ $i -lt $total ]; do
    if test -f ${this_jail_tls_dir}/$SERVER_NAME-${i}.pem; then
      echo_debug "[INFO] $SERVER_NAME-${i}.pem exists; skipping"
      i=$((i + 1))
      continue
    fi

    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$use_cfssl_config \
      $SERVER_CONFIG |
      cfssljson -bare "${this_jail_tls_dir}/$SERVER_NAME-${i}" || true # doesnt overwrite existing tokens

    i=$((i + 1))
  done

  chmod_cert_files
}

create_client_cert() {
  local total=${1:-1}
  local use_ca_cn=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local CLIENT_NAME=${4:-$CLIENT_NAME}
  local use_cfssl_config_name=${5:-$CFSSL_CONFIG_NAME}

  local this_jail_tls_dir="${JAIL}/${use_ca_cn}/tls"
  local CA_CERT="${this_jail_tls_dir}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${this_jail_tls_dir}/${CA_PEM_NAME}-key.pem"
  create_tls_dir $this_jail_tls_dir

  local CN_CONFIG_DIR="${CFSSL_DIR}/${use_ca_cn}"
  local CLIENT_CONFIG="${CN_CONFIG_DIR}/csr.client.${CLIENT_NAME}.json"
  throw_missing_file $CLIENT_CONFIG 404 'couldnt find client csr config'

  local use_cfssl_config="$(get_cfssl_config $use_cfssl_config_name $CN_CONFIG_DIR)"

  echo_debug "creating $total client certificates"

  declare -i i=0
  while [ $i -lt $total ]; do
    if test -f ${this_jail_tls_dir}/$CLIENT_NAME-${i}.pem; then
      echo_debug "[INFO] $CLIENT_NAME-${i}.pem exists; skipping"
      i=$((i + 1))
      continue
    fi

    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$use_cfssl_config \
      $CLIENT_CONFIG |
      cfssljson -bare "${this_jail_tls_dir}/$CLIENT_NAME-${i}" || true # doesnt overwrite existing tokens

    i=$((i + 1))
  done

  chmod_cert_files
}

create_cli_cert() {
  local total=${1:-1}
  local use_ca_cn=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local CLI_NAME=${4:-$CLI_NAME}
  local use_cfssl_config_name=${5:-$CFSSL_CONFIG_NAME}

  local this_jail_tls_dir="${JAIL}/${use_ca_cn}/tls"
  local CA_CERT="${JAIL_DIR_TLS}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${JAIL_DIR_TLS}/${CA_PEM_NAME}-key.pem"
  create_tls_dir $this_jail_tls_dir

  local CN_CONFIG_DIR="${CFSSL_DIR}/${use_ca_cn}"
  local CLI_CONFIG="${CN_CONFIG_DIR}/csr.cli.${CLI_NAME}.json"
  throw_missing_file $CLI_CONFIG 404 'couldnt find cli csr config'

  local use_cfssl_config="$(get_cfssl_config $use_cfssl_config_name $CN_CONFIG_DIR)"

  echo_debug "creating $total cli certificates"

  i=0
  while [ $i -lt $total ]; do
    if test -f "${this_jail_tls_dir}/$CLI_NAME-${i}.pem"; then
      echo_debug "[INFO] $CLI_NAME-${i}.pem exists; skipping"
      i=$((i + 1))
      continue
    fi

    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$use_cfssl_config \
      -profile=client \
      $CLI_CONFIG |
      cfssljson -bare "${this_jail_tls_dir}/$CLI_NAME-${i}" || true # doesnt overwrite existing tokens
    i=$((i + 1))
  done

  chmod_cert_files
}

######################## PROGRAM
cmd=${1:-''}

case $cmd in
info)
  what=${2:-''}
  case $what in
  cert)
    pem_file="${JAIL_DIR_TLS}/${3:?'pem name is required'}.pem"
    throw_missing_file $pem_file 404 'couldnt find local cert file'

    echo_debug 'retrieving data from local certificate file'
    cfssl certinfo -cert $pem_file
    ;;
  csr)
    csr_file="${JAIL_DIR_TLS}/${3:?'csr name is required'}.csr"
    throw_missing_file $csr_file 404 'couldnt find local csr file'

    echo_debug 'retrieving data from local CSR file'
    cfssl certinfo -csr $csr_file
    ;;
  *) invalid_request ;;
  esac
  ;;
create)
  what=${2:-''}
  case $what in
  rootca)
    use_ca_cn=${3:-''}
    use_ca_pem_name=${4:-''}

    create_root_ca $use_ca_cn $use_ca_pem_name
    ;;
  server)
    use_total=${3:-''}
    use_ca_cn=${4:-''}
    use_ca_pem_name=${5:-''}
    use_server_name=${6:-''}
    use_cfssl_config=${7-''}

    create_server_cert \
      $use_total \
      $use_ca_cn \
      $use_ca_pem_name \
      $use_server_name \
      $use_cfssl_config
    ;;
  client)
    use_total=${3:-''}
    use_ca_cn=${4:-''}
    use_ca_pem_name=${5:-''}
    use_client_name=${6:-''}
    use_cfssl_config=${7-''}

    create_client_cert \
      $use_total \
      $use_ca_cn \
      $use_ca_pem_name \
      $use_client_name \
      $use_cfssl_config
    ;;
  cli)
    use_total=${3:-''}
    use_ca_cn=${4:-''}
    use_ca_pem_name=${5:-''}
    use_cli_name=${6:-''}
    use_cfssl_config=${7-''}

    create_cli_cert \
      $use_total \
      $use_ca_cn \
      $use_ca_pem_name \
      $use_cli_name \
      $use_cfssl_config
    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
