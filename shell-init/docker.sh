#!/usr/bin/env bash

# @see https://www.digitalocean.com/community/tutorials/how-to-remove-docker-images-containers-and-volumes
# @see https://docs.docker.com/config/formatting/

export DOCKER_CLI_EXPERIMENTAL=enabled
# usage:
# docker ps --format="$DOCKER_FORMAT"
export DOCKER_FORMAT="ID\t{{.ID}}\nNAME\t{{.Names}}\nIMAGE\t{{.Image}}\nPORTS\t{{.Ports}}\nCOMMAND\t{{.Command}}\nCREATED\t{{.CreatedAt}}\nSTATUS\t{{.Status}}\n"

dk_show_hack_user_group() {
  echo -e "\nto hack /etc/{passwd,group}\ndepending if user/group exists\n\n"
  echo 'grep -qE "^uname:" ./etc/passwd && "add user&group" || "replace user&group"'
  echo 'replace USER_ID and GROUP_ID only:'
  echo 'RUN sed -i "s/^uname:.*:[0-9]\{1,\}:[0-9]\{1,\}:/uname:x:$USER_ID:$GROUP_ID:/i" /etc/passwd'
  echo 'RUN sed -i "s/^gname:.*:[0-9]\{1,\}:/gname:x:$GROUP_ID:/i" /etc/group'
}
export -f dk_show_hack_user_group

# startup a registry
# @see https://docs.docker.com/registry/deploying/
dk_start_registry() {
  docker run --rm -d -p 5001:5001 --restart=always --name registry registry:2
}
export -f dk_start_registry

dk_start_bash() {
  docker run --rm -it ubuntu:trusty bash
}
export -f dk_start_bash

dk_start_bash_host() {
  docker run --rm -it --network host ubuntu:trusty bash
}
export -f dk_start_bash_host

dk_imgs() {
  docker images --no-trunc -a --format="table {{.Repository}}\n\t{{.ID}}\n\t{{.Tag}}\n\n" | tac
}
export -f dk_imgs

dk_see_me() {
  docker run --rm -it alpine ping -c4 $(whats_my_ip)
}
export -f dk_see_me

dk_ps() {
  docker ps --no-trunc -a --format 'table {{.Names}}\n\t{{.Image}}\n\t{{.Status}}\n\t{{.Command}}\n\t{{.ID}}\n\n' | tac
}
export -f dk_ps

dk_d_remote_url() {
  sudo netstat -lntp | grep dockerd
}
export -f dk_d_remote_url

dk_logs() {
  journalctl -u docker.service
}
export -f dk_logs

# get netstats (use ss on ubuntu)
dk_d_ss() {
  sudo ss -asmpex | grep dockerd
}
export -f dk_d_ss

#echo image1 image2 three | xargall docker pull
dk_inspect() {
  docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
}
export -f dk_inspect

# see volumes for a container
dk_container_volumes() {
  docker inspect -f '{{range .Mounts}}{{println .Source}}{{println .Destination}}readWrite: {{.Mode}}{{println .RW}}{{end}}' $1
}
export -f dk_container_volumes

# get get ip addr for container
dk_container_network() {
  docker inspect -f '{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' $1
}
export -f dk_container_network

dk_rm_all() {
  docker network prune -a -ff || true
  docker stop $(docker ps -a -q) || true
  docker rm $(docker ps -a -q) || true
  docker rmi -f $(docker images -a -q) || true
  docker volume rm $(docker volume ls --filter dangling=true -q) || true

}
export -f dk_rm_all

dk_stop_rm_cunts() {
  docker ps -aq | xargs docker stop | xargs docker rm
}
export -f dk_stop_rm_cunts

dk_d_restart() {
  sudo systemctl daemon-reload
  sudo systemctl restart docker
}
export -f dk_d_restart
