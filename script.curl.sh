#!/usr/bin/env bash

set -e

# uses port based routing
DEFAULT_VAULT='https://dev.nirv.ai:8200'
# all other services use path based routing
DEFAULT_TARGET='https://dev.nirv.ai:8080'
DEFAULT_ORIGIN='http://poop.com'

USE_TARGET="${CURL_TARGET:-$DEFAULT_TARGET}"
USE_ORIGIN="${CURL_ORIGIN:-$DEFAULT_ORIGIN}"

case $1 in
vault)
  curl ${DEFAULT_VAULT}/v1/sys/init
  ;;
bff)
  curl ${USE_TARGET}/bff/v1/player/p/nirvai | jq
  ;;
cors)
  curl -H "Origin: $USE_ORIGIN" \
    --head \
    $USE_TARGET
  ;;
ssl)
  curl -X OPTIONS --verbose --head $USE_TARGET
  ;;
preflight)
  curl -H "Origin: $USE_ORIGIN" \
    -H "Access-Control-Request-Method: POST" \
    -H "Access-Control-Request-Headers: X-Requested-With" \
    --head \
    $USE_TARGET
  ;;
*)
  echo '$1 === cors|preflight|ssl|bff'
  ;;
esac
