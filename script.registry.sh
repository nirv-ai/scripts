#!/usr/bin/env sh

####################### READ FIRST
# @see [repo] https://github.com/distribution/distribution
# @see [docs] https://github.com/docker/docs/tree/main/registry
# @see [docs] https://github.com/docker/docs/blob/main/registry/configuration.md
## @see https://www.marcusturewicz.com/blog/build-and-publish-docker-images-with-github-packages/
## @see https://docs.github.com/en/actions/publishing-packages/publishing-docker-images
#######################

####################### FYI
# setup for a local registry for testing
# but definitely recommend canceling netflix
# so you can afford $5 (...$7) private registry with docker hub
## from hub: You are expected to be familiar with systems availability and scalability, logging and log processing, systems monitoring, and security 101. Strong understanding of http and overall network communications, plus familiarity with golang are certainly useful as well for advanced operations or hacking.
#######################

set -eu

# required
## e.g. export REG_CERTS_PATH=apps/nirvai-core-letsencrypt/dev-nirv-ai
REG_CERTS_PATH=${REG_CERTS_PATH:?REG_CERTS_PATH not set: exiting}

# optional
REG_DOMAIN=${REG_DOMAIN:-nirv.ai}
REG_SUBD=${REG_SUBD:-dev}
REG_HOST_PORT=${REG_HOST_PORT:-5000}
REG_CONT_PORT=${REG_CONT_PORT:-$REG_HOST_PORT}
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

########################### workflow fns

run_reg() {
  volumes

  real_certs_path="$(pwd)/$REG_CERTS_PATH"
  if ! test -d "$real_certs_path"; then
    echo
    echo "$real_certs_path not found"
    exit 1
  fi

  portmap="$REG_HOST_PORT:$REG_CONT_PORT"

  echo
  echo "creating registry: $REG_NAME on $portmap"
  echo "\tstore: $REG_VOL_NAME"
  echo "\tcerts: $real_certs_path"

  docker run -d -p $portmap \
    --name $REG_NAME \
    -v "$REG_VOL_NAME:/var/lib/registry" \
    -v "$real_certs_path:/etc/ssl/certs/$REG_DOMAIN/$REG_SUBD" \
    registry:2

  if [ "$?" -ne 0 ]; then
    echo "$REG_NAME already created: restarting..."
    docker restart $REG_NAME
  fi
}

push_img() {
  docker push $(get_img_fqdn $1)
}

tag_image() {
  docker tag $1 $(get_img_fqdn $1)
}

reset() {
  docker container stop $REG_FQDN
  docker container rm -v $REG_FQDN
}

cmds='start|pull'

case $1 in
run) run_reg ;;
push)
  image=${2:?'syntax "push imageName"'}
  pull_img $image
  ;;
tag)
  syntax='syntax "tag thisImage:tagName"'}
  thisImage=${2:?$syntax}

  echo
  echo "tagging and pushing: $thisImage"
  tag_image $thisImage
  push_img $thisImage
  ;;
reset)
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
  ;;
*)
  echo
  echo "commands: $cmds"
  ;;
esac
