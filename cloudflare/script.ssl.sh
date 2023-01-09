#!/usr/bin/env bash

###### @see https://developer.hashicorp.com/nomad/tutorials/transport-security/security-enable-tls#node-certificates
## nomad & consul use the same certificate pattern
## server.DATACENTER.DOMAIN for server certs
## client.DATACENTER.DOMAIN for client serts
## CLI certs use client certs
######

set -euo pipefail

if ! type cfssl 2>&1 >/dev/null; then
  echo -e "install cfssl before continuing: \nhttps://github.com/cloudflare/cfssl#installation"
fi

# INTERFACE
## locations
SSL_CN=${SSL_CN:-"mesh.nirv.ai"}
ENV=${ENV:-'development'}
BASE_DIR=$(pwd)
JAIL="${BASE_DIR}/secrets/${SSL_CN}/${ENV}/tls"

######################## ERROR HANDLING
DEBUG="${NIRV_SCRIPT_DEBUG:-1}"
echo_debug() {
  if [ "$DEBUG" = 1 ]; then
    echo -e '\n\n[DEBUG] SCRIPT.CONSUL.SH\n------------'
    echo -e "$@"
    echo -e "------------\n\n"
  fi
}
invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see https://github.com/nirv-ai/docs/blob/main/cloudflare/README.md"

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

    ;;
  client)
    echo "creating client certificate"
    CA_CERT="${JAIL}/ca.pem"
    CA_PRIVKEY="${JAIL}/ca-key.pem"
    CLIENT_CONFIG="${JAIL}/cfssl.json"

    cfssl gencert \
      -ca=$CA_CERT \
      -ca-key=$CA_PRIVKEY \
      -config=$CLIENT_CONFIG \
      ./mesh.client.csr.json |
      cfssljson -bare "${JAIL}/client"

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
      ./mesh.cli.csr.json |
      cfssljson -bare "${JAIL}/cli"

    ;;
  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
