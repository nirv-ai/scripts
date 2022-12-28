#!/usr/bin/env bash

THISDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]%/}")" &>/dev/null && pwd)

source_bash_files() {
	shopt -s failglob

	for file in "$THISDIR"/script.*.sh; do
		echo "sourcing $file"
		# source "$file"
	done

	shopt -u failglob
}

source_bash_files
