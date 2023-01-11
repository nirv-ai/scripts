#!/usr/bin/env bash

set -e

# @see https://blog.marcusjanke.de/lets-encrypt-certificates-with-aws-96554612ab64
## has additional steps for importing created cert for use with AWS ACM

# to get creds see below
# @see bookofnoah/linux/bash_cli_fns/aws for the following fns
## aws_profile_set
## aws_get_temp_creds

DOMAIN=${DOMAIN:-'dev.nirv.ai'}
EMAIL=${EMAIL:-'noahedwardhall@gmail.com'}

docker run -it --rm --name certbot \
  --env AWS_ACCESS_KEY_ID=$AccessKeyId \
  --env AWS_SECRET_ACCESS_KEY=$SecretAccessKey \
  --env AWS_SESSION_TOKEN=$SessionToken \
  -v "$PWD:/etc/letsencrypt" \
  -v "$PWD:/var/lib/letsencrypt" \
  certbot/dns-route53 certonly \
  -d $DOMAIN \
  -m $EMAIL \
  --dns-route53
