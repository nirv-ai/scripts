#!/usr/bin/env bash

# terraform ----------------------------
tf() {
  terraform "#@"
}
tf_reset_aws_env_vars() {
  export TF_VAR_AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"
  export TF_VAR_AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"
  export TF_VAR_AWS_DEFAULT_REGION="$AWS_DEFAULT_REGION"
  export TF_VAR_AWS_SESSION_TOKEN="$AWS_SESSION_TOKEN"
  export TF_VAR_AWS_SECURITY_TOKEN="$AWS_SECURITY_TOKEN"
}
tf_plan() {
  tf init
  echo -e "resetting tf aws vars"
  tf_reset_aws_env_vars
  echo -e "running tf_fmt"
  tf_fmt
  echo -e "running tf_validate"
  tf_validate
  echo -e "generating tfplan file"

  # if using terraform cloud, ensure its setup to run local
  tf_plan_local
}
tf_plan_local() {
  terraform plan -out tfplan
}
tf_plan_destroy() {
  tf init
  echo -e "resetting tf aws vars"
  tf_reset_aws_env_vars
  echo -e "running tf_fmt"
  tf_fmt
  echo -e "running tf_validate"
  tf_validate
  echo -e "generating destroy.tfplan file"

  tf plan -destroy -out destroy.tfplan
}
tf_apply() {
  echo -e "resetting tf aws vars"
  tf_reset_aws_env_vars
  if [ ! -z "$1" ]; then
    echo -e 'applying local tfplan'
    tf apply
  else
    echo -e 'applying terrarform cloud tfplan'
    tf apply
  fi
}
tf_output() {
  tf output --json
}
tf_show() {
  echo -e "getting current state of infrastructre"
  # if using terraform cloud: ensure tf is set to run locally
  echo -e "getting current state drift from tfplan"
  tf show tfplan
  echo ""
  echo -e "we mare managing the following resources:"
  tf_statelist
}
tf_graph() {
  tf graph -plan tfplan
}
tf_destroy() {
  tf apply destroy.tfplan
}
tf_fmt() {
  tf fmt
}
tf_validate() {
  tf validate
}
tf_state_list() {
  tf state list
}
tf_state_pull() {
  tf state pull
}
tf_state_rm() {
  tf state rm $1
}
tf_state_show() {
  tf state show
}
tf_refresh() {
  tf apply -refresh-only
}
