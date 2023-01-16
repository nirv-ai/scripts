#!/usr/bin/env bash

# CUNT_PREFIX: should generally be ${COMPOSE_PROJECT_NAME}-
# then the container name will be $CUNT_PREFIX-serviceName-indexNumber
CUNT_PREFIX=${CUNT_PREFIX:-'nirvai-'}

# gets the first container with the matching name
# TODO: as a last resort, do a *$1* grep to get any matching container
get_cunt_id() {
  # perhaps they passed the containers full name
  local container_id=$(docker ps -aqf "name=^${1}$")

  if test ${#container_id} -gt 6; then
    echo $container_id
  else # try with the prefix
    container_name_with_prefix="${CUNT_PREFIX}${1}"
    container_id=$(docker ps -aqf "name=^${container_name_with_prefix}" | head -n 1)
    if test ${#container_id} -gt 6; then
      echo $container_id
    fi
  fi

  echo ""
}
