#!/usr/bin/env bash

# ^ enable command completion
[ -f /usr/local/bin/aws_completer ] && complete -C '/usr/local/bin/aws_completer' aws

aws_config_manual() {
  sudo aws configure
}
export -f aws_config_manual

aws_config_current() {
  aws configure list
}
export -f aws_config_current

aws_profile_list() {
  aws configure list-profiles
}
export -f aws_profile_list

aws_accounts() {
  aws iam list-account-aliases
}
export -f aws_accounts

aws_whoami() {
  aws sts get-caller-identity
}
export -f aws_whoami

aws_pg_versions() {
  aws rds describe-db-engine-versions --default-only --engine postgres
}
export -f aws_pg_versions

aws_config_edit() {
  sudo nano ~/.aws/config
}
export -f aws_config_edit

aws_creds_edit() {
  sudo nano ~/.aws/credentials
}
export -f aws_creds_edit

aws_s3_list() {
  aws s3 ls
}
export -f aws_s3_list

aws_statemachines_list() {
  aws stepfunctions list-state-machines
}
export -f aws_statemachines_list

aws_get_temp_creds() {
  aws sts get-session-token --duration-seconds 900
}
export -f aws_get_temp_creds

aws_profile_set() {
  if [[ $# -eq 0 ]]; then
    echo '$1 === profile name; available profiles:'
    aws_profile_list
    return 1
  fi

  export AWS_DEFAULT_PROFILE="$1"

  aws_profile_to_env_vars "$1"
}
export -f aws_profile_set

aws_region_set() {
  if [[ $# -eq 1 ]]; then
    export AWS_DEFAULT_REGION="$1"
  fi
}
export -f aws_region_set

aws_keypair_create() {
  if [[ $# -eq 1 ]]; then
    aws ec2 create-key-pair --key-name "$1" --query 'KeyMaterial' --output text >"$1".pem
  fi
}
export -f aws_keypair_create

aws_subnet_create() {
  if [[ $# -eq 4 ]]; then
    echo 'subnet creation dry-run'
    echo 'ec2 create-subnet --dry-run --vpc-id "$1" --cidr-block "$2" --availability-zone "$3" --profile "$4"'

    aws ec2 create-subnet --dry-run --vpc-id "$1" --cidr-block "$2" --availability-zone "$3" --profile "$4"
  elif [[ $# -eq 5 ]]; then
    aws ec2 create-subnet --vpc-id "$1" --cidr-block "$2" --availability-zone "$3" --profile "$4"
  else
    echo 'expected params'
    echo '$1 vpc-id'
    echo '$2 cidr-block'
    echo '$3 az'
    echo '$4 profile'
    echo '$5 truthy: create resource'
  fi
}
export -f aws_subnet_create

aws_profile_to_env_vars() {
  # @see https://gist.github.com/mjul/f93ee7d144c5090e6e3c463f5f312587

  if [ "$#" -eq 0 ]; then
    echo "invalid args: \$1 === profile name"
    return 1
  fi

  export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id --profile $1)
  export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key --profile $1)
  export AWS_DEFAULT_REGION=$(aws configure get region --profile $1)
  export AWS_SESSION_TOKEN=$(aws configure get aws_session_token --profile "$1")
  export AWS_SECURITY_TOKEN=$(aws configure get aws_security_token --profile "$1")

  aws_whoami
}
export -f aws_profile_to_env_vars
