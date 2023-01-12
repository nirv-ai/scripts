#!/usr/bin/env bash

set -euo pipefail

invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see $DOCS_URI"

  echo -e $INVALID_REQUEST_MSG
}
