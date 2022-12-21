#!/usr/bin/env bash

###########################
# resets a container & image
# for something less destructive, use refresh script
###########################

set -e

SERVICE_PREFIX=${SERVICE_PREFIX:-nirvai}
POSTGRES_VOL_NAME=$SERVICE_PREFIX-core-postgres

create_volumes() {
  docker volume create $POSTGRES_VOL_NAME
}

build() {
  docker compose build --progress=plain
}

up() {
  docker compose up -d --remove-orphans
}

echo -e "running reset"

docker compose config

case $1 in
logs)
  id=${2:-""}
  if [[ -z $id ]]; then
    # TODO: update this to just grep for a matching file
    ## based on the short id
    echo -e "\n\n"
    echo -e 'grepping for log file\n'
    echo -e 'truncated ids'
    docker ps -a
    echo -e '\n\nfull ids'
    docker ps -a --no-trunc -q
    echo -e '\n\navailable log files'
    sudo ls -l /var/lib/docker/containers
    echo -e "\n"
    echo -e '------------------------------------------------'
    echo -e 'pass in a full container ID to see the log file'
    echo -e 'e.g. logs super_long_id_of_container'
    echo -e '------------------------------------------------'
    echo -e "\n\n"
    exit 0
  fi
  echo -e "displaying log file for container id $2"
  sudo cat /var/lib/docker/containers/$2/$2-json.log
  exit 0
  ;;
volumes)
  create_volumes
  docker volume ls
  ;;
core*)
  echo "resetting infrastructore for $1"
  if ! docker container kill $SERVICE_PREFIX-$1; then
    echo "container for service $1 already dead"
  else
    docker container rm $SERVICE_PREFIX-$1
    if [[ $1 == *"postgres" ]]; then
      echo "recreating $1 volumes"
      docker volume rm $POSTGRES_VOL_NAME
      create_volumes
    fi
  fi
  docker container prune -f
  echo "restarting server $1"
  docker compose build $1
  docker compose up -d $1 --remove-orphans
  docker compose convert $1
  ;;
*)
  echo 'resetting infrastructure'
  docker compose down
  dk_rm_all || true
  create_volumes
  build
  up
  ;;
esac

dk_ps
