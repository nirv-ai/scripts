#!/bin/false

request_sudo() {
  NEEDED_FOR=${1:?'sudo requires a reason'}
  if ! sudo -n true 2>/dev/null; then
    echo -e "\n[INFO] sudo requested: password required"
    echo -e "------------------------\n"
    echo -e "[REASON] $NEEDED_FOR"
    echo -e "[REQUIRED BY] $0"
    echo -e "\n------------------------"
  fi
}
