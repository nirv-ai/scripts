#!/usr/bin/env bash

set -e

DEFAULT_TARGET='https://dev.nirv.ai:8080/v1/'
DEFAULT_ORIGIN='http://poop.com'

USE_TARGET="${CURL_TARGET:-$DEFAULT_TARGET}"
USE_ORIGIN="${CURL_ORIGIN:-$DEFAULT_ORIGIN}"

case $1 in
bff)
  curl ${USE_TARGET}/v1/player/p/nirvai | jq
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
