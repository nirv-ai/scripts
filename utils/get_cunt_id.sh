#!/bin/false

# CUNT_PREFIX: should generally be ${COMPOSE_PROJECT_NAME}-
# then the container name will be $CUNT_PREFIX-serviceName-indexNumber
CUNT_PREFIX=${CUNT_PREFIX:-'nirvai-'}

# gets the first container with the matching name
get_cunt_id() {
  name="${1:?'partial service or container name required'}"
  # perhaps they passed the containers full name
  local container_id=$(docker ps -aqf "name=^${name}$")

  if test ${#container_id} -gt 6; then
    echo $container_id
    return 0
  fi

  # try with the prefix
  container_name_with_prefix="${CUNT_PREFIX}${name}"
  container_id=$(docker ps -aqf "name=^${container_name_with_prefix}" | head -n 1)
  if test ${#container_id} -gt 6; then
    echo $container_id
    return 0
  fi

  # get any matching container
  container_id=$(docker ps -aqf "name=${name}" | head -n 1)
  if test ${#container_id} -gt 6; then
    echo $container_id
    return 0
  fi

  echo ""
  return 1
}
