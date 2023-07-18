#!/usr/bin/env bash

# TODOs:
## this doesnt support aws cloudformation package ... cmd. see the docs
alias awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=${DEFAULT_REGION:-$AWS_DEFAULT_REGION} aws --endpoint-url=http://${LOCALSTACK_HOST:-localhost}:4566"

# localstack takes too long to type
lstack() {
  localstack "$@"
}
