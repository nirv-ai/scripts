#!/usr/bin/env bash

set -e

# you must first have a domain setup with route53
DOMAIN=${DOMAIN:-'dev.nirv.ai'}
EMAIL=${EMAIL:-'noahedwardhall@gmail.com'}

docker run --rm --name certbot \
  --env AWS_ACCESS_KEY_ID=$AccessKeyId \
  --env AWS_SECRET_ACCESS_KEY=$SecretAccessKey \
  --env AWS_SESSION_TOKEN=$SessionToken \
  -v "$PWD:/etc/letsencrypt" \
  -v "$PWD:/var/lib/letsencrypt" \
  certbot/dns-route53 certonly \
  -d $DOMAIN \
  -m $EMAIL \
  --dns-route53 \
  --agree-tos \
  --non-interactive
