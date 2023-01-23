#!/bin/false

## by using this file
## you help to enforce a common error interface
trap 'catch_then_exit $? $LINENO' ERR # EXIT useless when used with ERR

echo_err() {
	echo -e "$@" 1>&2
}
catch_then_exit() {
	if [ "$1" != "0" ]; then
		NIRV_SCRIPT_DEBUG=1
		echo_debug_interface
		echo_err "[CODE/LINE]: $1/$2"
	fi
}
throw_missing_file() {
	filepath=${1:?'file path is required'}
	code=${2:?'error code is required'}
	help=${3:?'help text is required'}

	if test ! -f "$filepath"; then
		cat <<-EOF >&2
			------------------------
			[ERROR] file is required
			[STATUS] $code
			[REQUIRED FILE] $filepath
			[REQUIRED BY] $0
			[HELP] $help
			------------------------
		EOF
		exit 1
	fi
}
throw_missing_dir() {
	dirpath=${1:?'dir path is required'}
	code=${2:?'error code is required'}
	help=${3:?'help text is required'}

	if test ! -d "$dirpath"; then
		cat <<-EOF >&2
			------------------------
			[ERROR] directory is required
			[STATUS] $code
			[REQUIRED DIR] $dirpath
			[REQUIRED BY] $0
			[HELP] $help
			------------------------
		EOF
		exit 1
	fi
}
throw_missing_program() {
	program=${1:?'program name is required'}
	code=${2:?'error code is required'}
	help=${3:?'help text is required'}

	if ! type $1 2>&1 >/dev/null; then
		cat <<-EOF >&2
			------------------------
			[ERROR] executable $program is required and must exist in your path
			[STATUS] $code
			[REQUIRED BY] $0
			[HELP] $help
			------------------------
		EOF
		exit 1
	fi
}
