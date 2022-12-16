#!/usr/bin/env bash

set -e

# you must first have a domain setup with route53

docker run --rm --name certbot \
  --env AWS_ACCESS_KEY_ID=$AccessKeyId \
  --env AWS_SECRET_ACCESS_KEY=$SecretAccessKey \
  --env AWS_SESSION_TOKEN=$SessionToken \
  -v "$PWD:/etc/letsencrypt" \
  -v "$PWD:/var/lib/letsencrypt" \
  certbot/dns-route53 certonly \
  -d dev.nirv.ai \
  -m noahedwardhall@gmail.com \
  --dns-route53 \
  --agree-tos \
  --non-interactive
