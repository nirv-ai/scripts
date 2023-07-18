#!/usr/bin/env bash

awsl() {
  # @see https://github.com/localstack/awscli-local
  # TODOs: this doesnt support aws cloudformation package ... cmd. see the docs and test for that cmd to fix it
  # runs in subshell so the exports dont pollute the env
  (
    export AWS_ACCESS_KEY_ID=test
    export AWS_SECRET_ACCESS_KEY=test
    export AWS_DEFAULT_REGION=${DEFAULT_REGION:-$AWS_DEFAULT_REGION}
    aws --endpoint-url=http://${LOCALSTACK_HOST:-localhost}:4566 "$@"
  )
}

lstack() {
  localstack "$@"
}

tfl() {
  # @see https://docs.localstack.cloud/user-guide/integrations/terraform/
  tflocal "$@"
}

saml() {
  # @see pip install aws-sam-cli-local
  samlocal "$@"
}
