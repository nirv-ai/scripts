#!/usr/bin/env sh

####################### READ FIRST
# @see [repo] https://github.com/distribution/distribution
# @see [docs] https://github.com/docker/docs/tree/main/registry
## @see https://www.marcusturewicz.com/blog/build-and-publish-docker-images-with-github-packages/
## @see https://docs.github.com/en/actions/publishing-packages/publishing-docker-images
#######################

####################### FYI
# setup for a local registry for testing
# but definitely recommend canceling netflix
# so you can afford $5 private registry with docker hub
#######################

set -eu

# required
REG_CERTS_PATH=${REG_CERTS_PATH:?REG_CERTS_PATH not set: exiting}

# optional
REG_DOMAIN=${REG_DOMAIN:-nirv.ai}
REG_SUBD=${REG_SUBD:-dev}
REG_HOST_PORT=${REG_HOST_PORT:-5000}
REG_CONT_PORT=${REG_CONT_PORT:-$REG_HOST_PORT}
REG_VOL_NAME=${REG_VOL_NAME:-"${REG_SUBD}_registry"}

volumes() {
  create volume $REG_VOL_NAME || true
}

run_reg() {
  volumes

  if test ! -f "$REG_CERTS_PATH"; then
    echo -e "$REG_CERTS_PATH not found"
    exit 1
  fi

  docker run -d -p $REG_HOST_PORT:$REG_CONT_PORT \
    -v $REG_VOL_NAME:/var/lib/registry \
    -v $REG_CERTS_PATH:/etc/ssl/certs/$DOMAIN/$SUBD

}
