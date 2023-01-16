#!/bin/false

## by using this file
## you help to enforce a common help messages for consumers
# set $DOCS_URI in your script pointing to your docs-repo/your-service/README.md

invalid_request() {
  local INVALID_REQUEST_MSG="invalid request: @see $DOCS_URI"

  echo_err $INVALID_REQUEST_MSG
}
