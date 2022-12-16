#!/usr/bin/env bash
# @see https://stackoverflow.com/questions/27947982/haproxy-unable-to-load-ssl-private-key-from-pem-file
## ^ was required for using letsencrypt certs with haproxy tls
## not required for hashicorp vault

set -e

for file in ./live/dev.nirv.ai/*.pem; do
  openssl x509 -in $file -text || true
done

echo 'creating combined fullchain + priv key pem file as combined.pem'
cat ./live/dev.nirv.ai/fullchain.pem ./live/dev.nirv.ai/privkey.pem >./live/dev.nirv.ai/combined.pem
ls ./live/dev.nirv.ai
