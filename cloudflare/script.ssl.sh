#!/usr/bin/env bash

######
## @see https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#node-certificates
## @see https://github.com/cloudflare/cfssl/wiki/Creating-a-new-CSR
## nomad & consul use the same certificate pattern, so shall we
## server.DATACENTER.DOMAIN for server certs
## SVC_NAME.DATACENTER.DOMAIN for client serts
## CLI certs use client certs
######

set -euo pipefail

######################## INTERFACE
NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/cfssl/README.md'

SCRIPTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)
SCRIPTS_DIR_PARENT=$(dirname $SCRIPTS_DIR)

CONFIG_DIR_NAME=${CONFIG_DIR_NAME:-'configs'}
SECRET_DIR_NAME=${SECRET_DIR_NAME:-'secrets'}
CA_CN=${CA_CN:-'mesh.nirv.ai'}

JAIL="${SCRIPTS_DIR_PARENT}/${SECRET_DIR_NAME}/${CA_CN}"
CONFIG_DIR="${SCRIPTS_DIR_PARENT}/${CONFIG_DIR_NAME}/cfssl"

declare -A EFFECTIVE_INTERFACE=(
  [CA_CN]=$CA_CN
  [CONFIG_DIR]=$CONFIG_DIR
  [JAIL]=$JAIL
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  [SCRIPTS_DIR]=$SCRIPTS_DIR
)

######################## UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## CREDIT CHECK
echo_debug_interface
throw_missing_program cfssl 400 "sudo apt install golang-cfssl"
throw_missing_dir $JAIL 400 "mkdir -p $JAIL"

######################## FNS
## reusable
create_tls_dir() {
  mkdir -p $JAIL/tls
}
chmod_cert_files() {
  throw_missing_dir $JAIL/tlx 500 "\$JAIL/tls should exist before calling this fn"

  sudo chmod 0644 $JAIL/*.pem
  sudo chmod 0640 $JAIL/*key.pem
}
## workflows
######################## PROGRAM
chmod_cert_files
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
    echo 'creating rootca keys'
    mkdir -p $JAIL
    cfssl genkey -initca ./mesh.rootca.csr.json | cfssljson -bare $JAIL/ca
    sudo chmod 0644 $JAIL/*.pem
    sudo chmod 0640 $JAIL/*key.pem
    ;;
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
