#!/bin/false

curl_it() {
  echo_debug "[url]: $1\n[args]: ${@:2}\n------------\n\n"

  curlargs='-H "Connection: close"'

  if [ "$NIRV_SCRIPT_DEBUG" = 1 ]; then
    curlargs="$curlargs -v"
  else
    curlargs="$curlargs -s"
  fi

  curl $curlargs --url $1 "${@:2}" | jq
}
