#!/usr/bin/env bash

# inspired by https://github.com/hashicorp-education/learn-consul-get-started-vms/tree/main/scripts

set -euo pipefail

# interface
BASE_DIR=$(pwd)
REPO_DIR=$BASE_DIR/core
APPS_DIR=$REPO_DIR/apps
APP_PREFIX=nirvai
CONSUL_INSTANCE_DIR_NAME=core-consul
CONSUL_SERVICE_NAME=core_consul
NIRV_SCRIPT_DEBUG=0

DATACENTER="us-east"
DOMAIN="mesh.nirv.ai"
CONSUL_INSTANCE_SRC_DIR=$APPS_DIR/$APP_PREFIX-$CONSUL_INSTANCE_DIR_NAME/src
CONSUL_INSTANCE_SRC_DIR="${CONSUL_INSTANCE_SRC_DIR:-''}"

CONSUL_INSTANCE_CONFIG_DIR="${CONSUL_INSTANCE_SRC_DIR}/config"
CONSUL_CONFIG_TARGET="${CONSUL_INSTANCE_CONFIG_DIR}/${CONSUL_CONFIG_TARGET:-''}"
CONSUL_DATA_DIR="/etc/consul/data"
CONSUL_CONFIG_DIR="/etc/consul/config"
