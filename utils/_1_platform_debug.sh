#!/bin/false

## by using this file
## you help to enforce a common debug interface

echo_debug() {
	if test $NIRV_SCRIPT_DEBUG != 0; then
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
echo_info() {
	if test $NIRV_SCRIPT_SILENT = 0; then
		echo -e "\n\n[INFO] $0\n------------------------\n"
		echo -e "$@"
		echo -e "\n------------------------\n\n"
	fi
}
