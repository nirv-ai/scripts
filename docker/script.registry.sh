#!/usr/bin/env bash

# TODO: https://github.com/docker/docs/blob/main/registry/deploying.md#restricting-access

set -euo pipefail

####################### SETUP
DOCS_URI='https://github.com/nirv-ai/docs/blob/main/docker/README.md'
SCRIPTS_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)"

SCRIPTS_DIR_PARENT="$(dirname $SCRIPTS_DIR)"

# PLATFORM UTILS
for util in $SCRIPTS_DIR/utils/*.sh; do
  source $util
done

######################## INTERFACE
CERTS_DIR_CUNT=${CERTS_DIR_CUNT:-/run/secrets}
CERTS_DIR_HOST=${CERTS_DIR_HOST:-/etc/ssl/certs}
REG_HOST_PORT=${REG_HOST_PORT:-5000}
REG_HOSTNAME=${REG_HOSTNAME:-dev.nirv.ai}
REG_NAME=${REG_NAME:-registry}
REG_PRVKEY_NAME=${REG_PRVKEY_NAME:-privkey.pem}
REG_PUBKEY_NAME=${REG_PUBKEY_NAME:-fullchain.pem}
REG_VOL_NAME=${REG_VOL_NAME:-registry_volume}

REG_FQDN="${REG_HOSTNAME}:${REG_HOST_PORT}"

# add vars that should be printed when NIRV_SCRIPT_DEBUG=1
declare -A EFFECTIVE_INTERFACE=(
  [DOCS_URI]=$DOCS_URI
  [SCRIPTS_DIR_PARENT]=$SCRIPTS_DIR_PARENT
  [CERTS_DIR_CUNT]=$CERTS_DIR_CUNT
  [REG_NAME]=$REG_NAME
  [REG_VOL_NAME]=$REG_VOL_NAME
  [REG_FQDN]=$REG_FQDN
)

######################## CREDIT CHECK
echo_debug_interface

######################## FNS

get_img_fqdn() {
  echo "$REG_FQDN/$1"
}

create_reg_volume() {
  echo_debug "creating volume $REG_VOL_NAME"
  docker volume create $REG_VOL_NAME || true
}

push_img() {
  image=${1:?'image must be a valid identifier'}
  echo_debug "pushing image: $image"
  docker push $image
}
########################### workflow fns

run_reg() {
  local host_certs="${CERTS_DIR_HOST}/${REG_HOSTNAME}"
  local reg_pub_key="${host_certs}/${REG_PUBKEY_NAME}"
  local reg_prv_key="${host_certs}/${REG_PRVKEY_NAME}"

  throw_missing_file $reg_pub_key 400 'public key required for tls'
  throw_missing_file $reg_prv_key 400 'prvate key required for tls'

  create_reg_volume

  portmap="$REG_HOST_PORT:443"
  CUNT_PUBKEY=$CERTS_DIR_CUNT/$REG_PUBKEY_NAME
  CUNT_PRVKEY=$CERTS_DIR_CUNT/$REG_PRVKEY_NAME

  echo_info "creating registry\n[NAME] $REG_NAME:$REG_HOST_PORT"

  docker run -d -p $portmap \
    --name $REG_NAME \
    --restart unless-stopped \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=$CUNT_PUBKEY \
    -e REGISTRY_HTTP_TLS_KEY=$CUNT_PRVKEY \
    -v "$REG_VOL_NAME:/var/lib/registry" \
    -v "$reg_pub_key:$CUNT_PUBKEY" \
    -v "$reg_prv_key:$CUNT_PRVKEY" \
    registry:2

  if [ "$?" -ne 0 ]; then
    echo "$REG_NAME already created: restarting..."
    docker restart $REG_NAME
  fi
}

reset_reg() {
  echo_debug "resetting $REG_NAME"
  docker stop $REG_NAME || true
  docker container rm $REG_NAME || true
  run_reg
}

tag_image() {
  thisImage=${1:?'syntax "tag thisImage:tagName"'}

  echo_debug "received image for tagging: $thisImage"

  case $thisImage in
  $REG_FQDN*)
    # echo_info 'consider using docker compose push for pretagged images'
    echo_debug 'image already tagged: pushing image'
    push_img $thisImage
    ;;
  *)
    taggedImage=$(get_img_fqdn $thisImage)
    echo_debug "image tagged: $taggedImage"
    docker tag $thisImage $taggedImage
    push_img $taggedImage
    # restricting latest images is bit overreaching
    # docker rmi -f $(docker images --filter="reference=*/*:latest*" -q)
    ;;
  esac

}
tag_running_containers() {
  echo_debug "tagging & pushing images for running containers\n$(docker ps --format '{{json .}}' | jq '.Image')"

  # haha got lucky on this one
  docker ps --format '{{json .}}' | jq '.Image' | while IFS= read -r cunt; do
    echo_debug "processing cunt: $cunt"

    # xargs  unquotes the cunts name
    tag_image $(echo $cunt | xargs)
  done
}

######################## EXECUTE
cmd=${1:-''}
case $cmd in
run) run_reg ;;
reset) reset_reg ;;
tag) tag_image $2 ;;
tag-running) tag_running_containers ;;
*) invalid_request ;;
esac
