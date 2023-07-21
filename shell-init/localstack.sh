#!/usr/bin/env bash

## TODOs:
### move this into nirv-ai/scripts once its all setup

######################## aws local
awsl() {
  # @see https://github.com/localstack/awscli-local
  # TODOs:
  ## ^ this doesnt support aws cloudformation package ... cmd. see the docs and test for that cmd to fix it

  #### ensure you have ~/.aws/{config,credentials} setup
  ### config
  # [profile localstack]
  # region = us-east-1
  # output = json
  # endpoint_url = http://localhost:4566
  ### credentials
  # [localstack]
  # aws_access_key_id=test
  # aws_secret_access_key=test

  export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile localstack)
  export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile localstack)
  export AWS_DEFAULT_REGION=$(aws configure get region --profile localstack)
  export AWS_ENDPOINT_URL=$(aws configure get endpoint_url --profile localstack)

  # for some reason this fails if we rely on AWS_ENDPOINT_URL env var
  aws --endpoint-url=http://${LOCALSTACK_HOST:-localhost}:4566 "$@"
}

######################## localstack
lstack() {
  localstack "$@"
}
lstack_version() {
  lstack --version
}
lstack_logs() {
  lstack logs
}
lstack_dk_health() {
  curl localhost:4566/_localstack/health | jq
}
######################## terraform local
tfl() {
  # @see https://docs.localstack.cloud/user-guide/integrations/terraform/
  tflocal "$@"
}

######################## sam local
saml() {
  # @see https://github.com/localstack/aws-sam-cli-local
  samlocal "$@"
}
