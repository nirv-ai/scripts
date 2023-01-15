#!/usr/bin/env bash

set -euo pipefail

NIRV_SCRIPT_DEBUG="${NIRV_SCRIPT_DEBUG:-0}"

echo_debug() {
  if [ "$NIRV_SCRIPT_DEBUG" = 1 ]; then
    echo -e "\n\n[DEBUG] $0\n------------------------\n"
    echo -e "$@"
    echo -e "\n------------------------\n\n"
  fi
}
echo_debug_interface() {
  local kv=''
  for k in "${!EFFECTIVE_INTERFACE[@]}"; do
    kv="${kv}\n${k}=${EFFECTIVE_INTERFACE[$k]}"
  done

  echo_debug "${kv}\n"
}
