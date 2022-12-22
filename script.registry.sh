#!/usr/bin/env sh

# TODO: https://github.com/docker/docs/blob/main/registry/deploying.md#restricting-access

set -eu

# required
## e.g. export REG_CERTS_PATH=apps/nirvai-core-letsencrypt/dev-nirv-ai
REG_CERTS_PATH=${REG_CERTS_PATH:?REG_CERTS_PATH not set: exiting}

# optional
REG_DOMAIN=${REG_DOMAIN:-nirv.ai}
REG_SUBD=${REG_SUBD:-dev}
REG_HOST_PORT=${REG_HOST_PORT:-5000}
REG_HOST_NAME=${REG_HOST_NAME:-"${REG_SUBD}.${REG_DOMAIN}"}
REG_FQDN="${REG_HOST_NAME}:${REG_HOST_PORT}"
REG_VOL_NAME=${REG_VOL_NAME:-${REG_SUBD}_registry}
REG_NAME=${REG_NAME:-$REG_VOL_NAME}

############################ utility fns

get_img_fqdn() {
  echo "$REG_FQDN/$1"
}

volumes() {
  echo
  echo "creating volume $REG_VOL_NAME"
  docker volume create $REG_VOL_NAME || true
}

push_img() {
  image=$(get_img_fqdn $1)
  echo "pushing image: $image"
  docker push $image
}
########################### workflow fns

run_reg() {
  volumes

  real_certs_path="$(pwd)/$REG_CERTS_PATH"
  if ! test -d "$real_certs_path"; then
    echo
    echo "$real_certs_path not found"
    exit 1
  fi

  portmap="$REG_HOST_PORT:443"
  CUNT_CERT_PATH=/etc/ssl/certs
  CUNT_LIVE_CERT_PATH=$CUNT_CERT_PATH/live/$REG_HOST_NAME

  echo
  echo "creating registry: $REG_NAME on $portmap"
  echo "\tstore: $REG_VOL_NAME"
  echo "\tcerts: $real_certs_path"

  docker run -d -p $portmap \
    --name $REG_NAME \
    --restart unless-stopped \
    -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
    -e REGISTRY_HTTP_TLS_CERTIFICATE=$CUNT_LIVE_CERT_PATH/fullchain.pem \
    -e REGISTRY_HTTP_TLS_KEY=$CUNT_LIVE_CERT_PATH/privkey.pem \
    -v "$REG_VOL_NAME:/var/lib/registry" \
    -v "$real_certs_path:$CUNT_CERT_PATH" \
    registry:2

  if [ "$?" -ne 0 ]; then
    echo "$REG_NAME already created: restarting..."
    docker restart $REG_NAME
  fi
}

reset_reg() {
  id=$(docker inspect --format="{{.Id}}" $REG_NAME) 2>/dev/null || true
  if test ! -z $id; then
    echo 'reviewing disk logs before resetting: this requires sudo'
    echo "id of previous registry: $id"
    logfile="/var/lib/docker/containers/$id/$id-json.log"
    sudo cat $logfile | jq
  fi

  echo
  echo "resetting $REG_NAME"
  docker stop $REG_NAME || true
  docker container rm $REG_NAME || true
  run_reg
}

tag_image() {
  thisImage=${1:?'syntax "tag thisImage:tagName"'}
  echo
  echo "tagging and pushing: $thisImage"
  docker tag $thisImage $(get_img_fqdn $thisImage)
  push_img $thisImage

  echo "removing (ignore if fail) original image sourced from hub"
  docker image remove -f $thisImage || true
  # docker rmi -f $(docker images --filter="reference=*/*:latest*" -q)
}
tag_running_containers() {
  echo 'tagging & pushing all running containers images'
  # echo $(docker inspect nirvai_core_ui | jq '.[] | {sha: .Image, name: .Name}')

  # haha got lucky on this one, docker format has 0 documentation
  docker ps --format '{{json .}}' | jq '.Image' | while IFS= read -r cunt; do
    echo
    echo "processing cunt: $cunt"

    # xargs  unquotes the cunts name
    tag_image $(echo $cunt | xargs)
  done
}

cmds='run|reset|rm|tag|tag_running'
cmd=${1:-''}
case $cmd in
run) run_reg ;;
reset) reset_reg ;;
tag) tag_image $2 ;;
tag_running) tag_running_containers ;;
*)
  echo
  echo "commands: $cmds"
  ;;
esac
