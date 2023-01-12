#!/usr/bin/env bash
# @see https://stackoverflow.com/questions/27947982/haproxy-unable-to-load-ssl-private-key-from-pem-file
## ^ was required for using letsencrypt certs with haproxy tls
## not required for hashicorp vault

# TODO: you can do better than this script

set -e

DOMAIN=${DOMAIN:-'dev.nirv.ai'}

for file in ./live/$DOMAIN/*.pem; do
  openssl x509 -in $file -text || true
done

echo 'creating combined fullchain + priv key pem file as combined.pem'
cat ./live/$DOMAIN/fullchain.pem ./live/$DOMAIN/privkey.pem >./live/$DOMAIN/combined.pem
ls ./live/$DOMAIN
