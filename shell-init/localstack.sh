#!/usr/bin/env bash

## @see https://github.com/localstack/awscli-local

# alias awslocal="AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test AWS_DEFAULT_REGION=${DEFAULT_REGION:-$AWS_DEFAULT_REGION} aws --endpoint-url=http://${LOCALSTACK_HOST:-localhost}:4566"

awslocal() {
  # TODOs: this doesnt support aws cloudformation package ... cmd. see the docs and test for that cmd to fix it
  # runs in subshell so the exports dont pollute the env
  (
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_DEFAULT_REGION=${DEFAULT_REGION:-$AWS_DEFAULT_REGION}
    aws --endpoint-url=http://${LOCALSTACK_HOST:-localhost}:4566 "$@"
  )
}

# localstack takes too long to type ;)
lstack() {
  localstack "$@"
}
