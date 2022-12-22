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

volumes() {
  echo
  echo "creating volume $REG_VOL_NAME"
  docker volume create $REG_VOL_NAME || true
}

run_reg() {
  volumes

  if ! test -d "$REG_CERTS_PATH"; then
    echo
    echo "$REG_CERTS_PATH not found"
    exit 1
  fi

  portmap="$REG_HOST_PORT:$REG_CONT_PORT"
  storage="$REG_VOL_NAME:/var/lib/registry"
  certs="$REG_CERTS_PATH:/etc/ssl/certs/$REG_DOMAIN/$REG_SUBD"

  echo
  echo "creating registry: $REG_NAME:$REG_HOST_PORT"
  echo "\tstore: $storage"
  echo "\tcerts: $certs"

  docker run -d -p $portmap \
    --name $REG_NAME registry:2 \
    --restart=always \
    -v $storage \
    -v $certs
}

reset() {
  docker container stop $REG_FQDN
  docker container rm -v $REG_FQDN
}

cmds='start|pull'

case $1 in
run) run_reg ;;
pull)
  image=${2:?'syntax "pull imageName"'}
  docker pull $REG_FQDN/$image
  ;;
tag)
  syntax='syntax "tag thisImage tagName"'}
  thisImage=${2:?$syntax}
  withTag=${3:?$syntax}
  newImage="$REG_FQDN/$withTag"
  echo
  echo "tagging and pushing: $newImage"
  docker tag $thisImage $newImage
  docker push $newImage
  ;;
*)
  echo
  echo "commands: $cmds"
  ;;
esac
