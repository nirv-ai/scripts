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
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/cfssl/README.md'
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-1}"

SCRIPTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)
SCRIPTS_DIR_PARENT=$(dirname $SCRIPTS_DIR)

CA_CN=${CA_CN:-'mesh.nirv.ai'}
CONFIG_DIR_NAME=${CONFIG_DIR_NAME:-'configs'}
SECRET_DIR_NAME=${SECRET_DIR_NAME:-'secrets'}
TLS_DIR_NAME=${TLS_DIR_NAME:-'tls'}

CFSSL_DIR="${SCRIPTS_DIR_PARENT}/${CONFIG_DIR_NAME}/cfssl"
JAIL="${SCRIPTS_DIR_PARENT}/${SECRET_DIR_NAME}/${CA_CN}"

JAIL_TLS="${JAIL}/${TLS_DIR_NAME}"

declare -A EFFECTIVE_INTERFACE=(
  [CA_CN]=$CA_CN
  [CFSSL_DIR]=$CFSSL_DIR
  [JAIL_TLS]=$JAIL_TLS
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  [SCRIPTS_DIR]=$SCRIPTS_DIR
)

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## CREDIT CHECK
echo_debug_interface

throw_missing_program cfssl 400 'sudo apt install golang-cfssl'
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
  cfssl genkey -initca $CA_CONFIG_FILE | cfssljson -bare $JAIL_TLS/$2
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
  rootca) create_root_ca ${3:-''} ${4:-'ca'} ;;
  server)
    total=${3:-1}
    echo "creating $total server certificates"
    CA_CERT="${JAIL}/ca.pem"
    CA_PRIVKEY="${JAIL}/ca-key.pem"
    SERVER_CONFIG="${JAIL}/cfssl.json"

    i=0
    while [ $i -lt $total ]; do
      cfssl gencert \
        -ca=$CA_CERT \
        -ca-key=$CA_PRIVKEY \
        -config=$SERVER_CONFIG \
        ./mesh.server.csr.json |
        cfssljson -bare "${JAIL}/server-${i}"
      i=$((i + 1))
    done

    sudo chmod 0644 $JAIL/*.pem
    sudo chmod 0640 $JAIL/*key.pem
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
