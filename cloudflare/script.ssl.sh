#!/usr/bin/env bash

######
## @see https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#node-certificates
## @see https://github.com/cloudflare/cfssl/wiki/Creating-a-new-CSR
######

set -euo pipefail

######################## INTERFACE
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/cfssl/README.md'
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-0}"
SCRIPTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)

SCRIPTS_DIR_PARENT=$(dirname $SCRIPTS_DIR)

# grouped by increasing order of dependency
CA_CN="${CA_CN:-mesh.nirv.ai}"
CA_PEM_NAME="${CA_PEM_NAME:-ca}"
CFSSL_CONFIG_NAME="${CFSSL_CONFIG_NAME:-cfssl.json}"
CLI_NAME="${CLI_NAME:-cli}"
CLIENT_NAME="${CLIENT_NAME:-client}"
CONFIG_DIR_NAME="${CONFIG_DIR_NAME:-configs}"
SECRET_DIR_NAME="${SECRET_DIR_NAME:-secrets}"
SERVER_NAME="${SERVER_NAME:-server}"
TLS_DIR_NAME="${TLS_DIR_NAME:-tls}"

CFSSL_DIR="${CFSSL_DIR:-$SCRIPTS_DIR_PARENT/$CONFIG_DIR_NAME/cfssl}"
JAIL="${JAIL:-$SCRIPTS_DIR_PARENT/$SECRET_DIR_NAME/$CA_CN}"

JAIL_DIR_TLS="${JAIL_DIR_TLS:-$JAIL/$TLS_DIR_NAME}"

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

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## CREDIT CHECK
echo_debug_interface

throw_missing_program cfssl 400 'sudo apt install golang-cfssl'
throw_missing_program cfssljson 400 'sudo apt install golang-cfssl'
throw_missing_program jq 400 'sudo apt install jq'

throw_missing_dir $CFSSL_DIR 400 'cant find certificate authority configuration files'
throw_missing_dir $JAIL 400 "mkdir -p $JAIL"

######################## FNS
## reusable
create_tls_dir() {
  mkdir -p $JAIL_DIR_TLS
}
chmod_cert_files() {
  throw_missing_dir $JAIL_DIR_TLS 500 'invoke $create_tls_dir before calling this fn'

  request_sudo "sudo required to chmod $JAIL_DIR_TLS/*.pem files"

  sudo chmod 0644 $JAIL_DIR_TLS/*.pem
  sudo chmod 0640 $JAIL_DIR_TLS/*key.pem
}

## actions
create_root_ca() {
  local CA_CONFIG_DIR="${CFSSL_DIR}/${1:-$CA_CN}"

  local CA_CONFIG_FILE="${CA_CONFIG_DIR}/csr.root.ca.json"

  throw_missing_file $CA_CONFIG_FILE 400 "root ca configuration file not found"

  echo_debug "creating rootca with config: $(cat $CA_CONFIG_FILE | jq)"
  create_tls_dir
  cfssl genkey -initca $CA_CONFIG_FILE | cfssljson -bare $JAIL_DIR_TLS/${2:-$CA_PEM_NAME}
  chmod_cert_files
}

create_server_cert() {
  local total=${1:-1}
  local CA_CN=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local SERVER_NAME=${4:-$SERVER_NAME}

  local CA_CERT="${JAIL_DIR_TLS}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${JAIL_DIR_TLS}/${CA_PEM_NAME}-key.pem"
  local CN_CONFIG_DIR="${CFSSL_DIR}/${CA_CN}"

  local SERVER_CONFIG="${CN_CONFIG_DIR}/csr.server.${SERVER_NAME}.json"
  throw_missing_file $SERVER_CONFIG 400 'couldnt find server csr config'

  if test -n ${5:-''}; then
    local CFFSL_CONFIG="${CN_CONFIG_DIR}/$5"
    throw_missing_file $CFFSL_CONFIG 400 'couldnt find server cfssl config'
  else
    local CFFSL_CONFIG="${CFSSL_DIR}/${CFSSL_CONFIG_NAME}"
    throw_missing_file $CFFSL_CONFIG 400 'couldnt find default cfssl config'
  fi

  echo_debug "creating $total server certificates"

  i=0
  while [ $i -lt $total ]; do
    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$CFFSL_CONFIG \
      $SERVER_CONFIG |
      cfssljson -bare "${JAIL_DIR_TLS}/$SERVER_NAME-${i}" || true # doesnt overwrite existing tokens
    i=$((i + 1))
  done

  chmod_cert_files
}

create_client_cert() {
  local total=${1:-1}
  local CA_CN=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local CLIENT_NAME=${4:-$CLIENT_NAME}

  local CA_CERT="${JAIL_DIR_TLS}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${JAIL_DIR_TLS}/${CA_PEM_NAME}-key.pem"
  local CN_CONFIG_DIR="${CFSSL_DIR}/${CA_CN}"

  local CLIENT_CONFIG="${CN_CONFIG_DIR}/csr.client.${CLIENT_NAME}.json"
  throw_missing_file $CLIENT_CONFIG 400 'couldnt find client csr config'

  if test -n ${5:-''}; then
    local CFFSL_CONFIG="${CN_CONFIG_DIR}/$5"
    throw_missing_file $CFFSL_CONFIG 400 'couldnt find client cfssl config'
  else
    local CFFSL_CONFIG="${CFSSL_DIR}/${CFSSL_CONFIG_NAME}"
    throw_missing_file $CFFSL_CONFIG 400 'couldnt find default cfssl config'
  fi

  echo_debug "creating $total client certificates"

  i=0
  while [ $i -lt $total ]; do
    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$CFFSL_CONFIG \
      $CLIENT_CONFIG |
      cfssljson -bare "${JAIL_DIR_TLS}/$CLIENT_NAME-${i}" || true # doesnt overwrite existing tokens
    i=$((i + 1))
  done

  chmod_cert_files
}

create_cli_cert() {
  local total=${1:-1}
  local CA_CN=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local CLI_NAME=${4:-$CLI_NAME}

  local CA_CERT="${JAIL_DIR_TLS}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${JAIL_DIR_TLS}/${CA_PEM_NAME}-key.pem"
  local CN_CONFIG_DIR="${CFSSL_DIR}/${CA_CN}"

  local CLI_CONFIG="${CN_CONFIG_DIR}/csr.cli.${CLI_NAME}.json"
  throw_missing_file $CLI_CONFIG 400 'couldnt find cli csr config'

  if test -n ${5:-''}; then
    local CFFSL_CONFIG="${CN_CONFIG_DIR}/$5"
    throw_missing_file $CFFSL_CONFIG 400 'couldnt find cli cfssl config'
  else
    local CFFSL_CONFIG="${CFSSL_DIR}/${CFSSL_CONFIG_NAME}"
    throw_missing_file $CFFSL_CONFIG 400 'couldnt find default cfssl config'
  fi

  echo_debug "creating $total cli certificates"

  i=0
  while [ $i -lt $total ]; do
    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$CFFSL_CONFIG \
      -profile=client \
      $CLI_CONFIG |
      cfssljson -bare "${JAIL_DIR_TLS}/$CLI_NAME-${i}" || true # doesnt overwrite existing tokens
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
    throw_missing_file $pem_file 400 'couldnt find local cert file'

    echo_debug 'retrieving data from local certificate file'
    cfssl certinfo -cert $pem_file
    ;;
  csr)
    csr_file="${JAIL_DIR_TLS}/${3:?'csr name is required'}.csr"
    throw_missing_file $csr_file 400 'couldnt find local csr file'

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
