#!/usr/bin/env bash

# @see https://www.cyberciti.biz/faq/linux-change-user-group-uid-gid-for-all-owned-files/
# @see https://www.cyberciti.biz/faq/how-do-i-find-all-the-files-owned-by-a-particular-user-or-group/?utm_source=Related_Tutorials&utm_medium=faq&utm_campaign=Apr_22_2022_EOP_TEXT
# @see https://www.cyberciti.biz/faq/freebsd-disable-ps-sockstat-command-information-leakage/?utm_source=Related_Tutorials&utm_medium=faq&utm_campaign=Apr_22_2022_EOP_TEXT

get_group_id() {
  echo $(id -g ${1:?'group name is required'})
}
export -f get_group_id

get_user_id() {
  echo $(id -u ${1:?'user name is required'})
}
export -f get_user_id

get_group() {
  echo $(getent group ${1:?'group name is required'})
}
export -f get_group

get_groups_self() {
  echo $(groups)
}
export -f get_groups_self

get_group_users() {
  echo $(getent group ${1:?'group name is required'})
}
export -f get_group_users

add_user_to_group() {
  group_name=${1:?'group name is required'}
  user_name=${2:-$USER}

  echo -e "sudo required: adding $user_name to system group $group_name\n"
  sudo usermod -aG $group_name $user_name
}
create_group_system() {
  group_name=${1:?'group name is required'}
  user_name=${2:-$USER}

  echo -e "sudo required: creating system group $group_name\n"

  sudo groupadd -fr $group_name
  add_user_to_group $group_name $user_name
}
export -f create_group_system

create_user_system() {
  user_name=${1:?system username required}

  echo -e "sudo required: creating system user $user_name"

  create_group_system $user_name
  sudo useradd -r -g $user_name -s /sbin/nologin $user_name
}
export -f create_user_system

rm_user() {
  user_name=${1:?user name required}

  echo -e "sudo required: deleting system user $user_name"

  sudo deluser $user_name
}
export -f rm_user
