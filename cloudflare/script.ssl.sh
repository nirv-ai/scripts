#!/usr/bin/env bash

######
## @see https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#node-certificates
## @see https://github.com/cloudflare/cfssl/wiki/Creating-a-new-CSR
##by default we use nomad & consul certificate pattern
## server.DATACENTER.DOMAIN for server certs
## SVC_NAME.DATACENTER.DOMAIN for client serts
## CLI certs use client certs
######

set -euo pipefail

######################## INTERFACE
# grouped by increasing order of dependency
CA_CN="${CA_CN:-mesh.nirv.ai}"
CA_PEM_NAME="${CA_PEM_NAME:-ca}"
CFSSL_CONFIG_NAME="${CFSSL_CONFIG_NAME:-cfssl.json}"
CONFIG_DIR_NAME="${CONFIG_DIR_NAME:-configs}"
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/cfssl/README.md'
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
SCRIPTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)
SECRET_DIR_NAME="${SECRET_DIR_NAME:-secrets}"
SERVER_CONFIG_NAME="${SERVER_CONFIG_NAME:-server}"
TLS_DIR_NAME="${TLS_DIR_NAME:-tls}"

SCRIPTS_DIR_PARENT=$(dirname $SCRIPTS_DIR)

CFSSL_DIR="${SCRIPTS_DIR_PARENT}/${CONFIG_DIR_NAME}/cfssl"
JAIL="${SCRIPTS_DIR_PARENT}/${SECRET_DIR_NAME}/${CA_CN}"

JAIL_TLS="${JAIL}/${TLS_DIR_NAME}"

CA_CERT="${JAIL_TLS}/${CA_PEM_NAME}.pem"
CA_PRIVKEY="${JAIL_TLS}/${CA_PEM_NAME}-key.pem"

declare -A EFFECTIVE_INTERFACE=(
  [CA_CERT]=$CA_CERT
  [CA_CN]=$CA_CN
  [CA_PEM_NAME]=$CA_PEM_NAME
  [CA_PRIVKEY]=$CA_PRIVKEY
  [CFSSL_CONFIG_NAME]=$CFSSL_CONFIG_NAME
  [CFSSL_DIR]=$CFSSL_DIR
  [JAIL_TLS]=$JAIL_TLS
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  [SCRIPTS_DIR]=$SCRIPTS_DIR
  [SERVER_CONFIG_NAME]=$SERVER_CONFIG_NAME
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
  mkdir -p $JAIL_TLS
}
chmod_cert_files() {
  throw_missing_dir $JAIL_TLS 500 'invoke $create_tls_dir before calling this fn'

  request_sudo "sudo required to chmod $JAIL_TLS/*.pem files"

  sudo chmod 0644 $JAIL_TLS/*.pem
  sudo chmod 0640 $JAIL_TLS/*key.pem
}

## actions
create_root_ca() {
  local CA_CONFIG_DIR="${CFSSL_DIR}/${1:-$CA_CN}"

  local CA_CONFIG_FILE="${CA_CONFIG_DIR}/csr.root.ca.json"

  throw_missing_file $CA_CONFIG_FILE 400 "root ca configuration file not found"

  echo_debug "creating rootca with config: $(cat $CA_CONFIG_FILE | jq)"
  create_tls_dir
  cfssl genkey -initca $CA_CONFIG_FILE | cfssljson -bare $JAIL_TLS/${2:-$CA_PEM_NAME}
  chmod_cert_files
}

create_server_cert() {
  local total=${1:-1}
  local CA_CN=${2:-$CA_CN}
  local CA_PEM_NAME=${3:-$CA_PEM_NAME}
  local SERVER_CONFIG_NAME=${4:-$SERVER_CONFIG_NAME}

  local CA_CERT="${JAIL_TLS}/${CA_PEM_NAME}.pem"
  local CA_PRIVKEY="${JAIL_TLS}/${CA_PEM_NAME}-key.pem"
  local CN_CONFIG_DIR="${CFSSL_DIR}/${CA_CN}"

  local SERVER_CONFIG="${CN_CONFIG_DIR}/csr.server.${SERVER_CONFIG_NAME}.json"
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
      cfssljson -bare "${JAIL_TLS}/$SERVER_CONFIG_NAME-${i}"
    i=$((i + 1))
  done

  chmod_cert_files
}

## workflows
######################## PROGRAM

cmd=${1:-''}

case $cmd in
info)
  who=${2:-''}
  case $who in
  rootca)
    what=${3:-''}
    case $what in
    cert)
      echo -e "\ninfo about cert & pubkey\n\n"
      cfssl certinfo -cert $JAIL/ca.pem
      ;;
    csr)
      echo "info about csr"
      cfssl certinfo -csr $JAIL/ca.csr
      ;;
    *) invalid_request ;;
    esac
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
    use_server_config=${6:-''}
    use_cfssl_config=${7-''}

    create_server_cert \
      $use_total \
      $use_ca_cn \
      $use_ca_pem_name \
      $use_server_config \
      $use_cfssl_config
    ;;
  client)
    svc_name=${3:?'svc_name is required'}
    echo "creating client certificate"
    CA_CERT="${JAIL}/ca.pem"
    CA_PRIVKEY="${JAIL}/ca-key.pem"
    CLIENT_CONFIG="${JAIL}/cfssl.json"

    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$CLIENT_CONFIG \
      ./mesh.client.csr.json |
      cfssljson -bare "${JAIL}/${svc_name}"

    sudo chmod 0644 $JAIL/*.pem
    sudo chmod 0640 $JAIL/*key.pem
    ;;
  cli)
    echo "creating command line certificate"
    CA_CERT="${JAIL}/ca.pem"
    CA_PRIVKEY="${JAIL}/ca-key.pem"
    CLI_CONFIG="${JAIL}/cfssl.json"

    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$CLI_CONFIG \
      -profile=client \
      ./mesh.cli.csr.json |
      cfssljson -bare "${JAIL}/cli"

    sudo chmod 0644 $JAIL/*.pem
    sudo chmod 0640 $JAIL/*key.pem
    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
