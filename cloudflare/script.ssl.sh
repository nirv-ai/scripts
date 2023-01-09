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
JAIL="${BASE_DIR}/secrets/${SSL_CN}/${ENV}"

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
    ENV=development
    mkdir -p $JAIL
    cfssl genkey -initca ./mesh.dev.rootca.csr.json | cfssljson -bare $JAIL/ca
    ;;

  *) invalid_request ;;
  esac
  ;;
*) invalid_request ;;
esac
