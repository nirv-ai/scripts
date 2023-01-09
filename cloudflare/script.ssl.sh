#!/usr/bin/env bash

set -euo pipefail

if ! type cfssl 2>&1 >/dev/null; then
  echo -e "install cfssl before continuing: \nhttps://github.com/cloudflare/cfssl#installation"
fi
