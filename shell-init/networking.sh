#!/usr/bin/env bash

cmd_time() {
    time "$@"
}
get_hosts() {
    getent hosts
}
get_networks() {
    getent networks
}
get_services() {
    getent services
}
get_response_headers() {
    if [[ $# -eq 1 ]]; then
        curl -I "$1"
    else
        echo "\$1 === url"
    fi
}
get_response_time() {
    if [[ $# -eq 1 ]]; then
        cmd_time get_response_headers "$1"
    else
        echo "\$1 === url"
    fi
}

do_response_dos() {
    if [[ $# -eq 1 ]]; then
        while true; do
            do_response_time "$1"
            sleep 0.1
        done
    else
        echo "\$1 === url"
    fi
}
wait_for_service_on_port() {
    if test $# -eq 2; then
        while true; do
            if test $(netstat -tulanp | grep "$2" | grep LISTEN); then
                echo "$1 is up on port $2"
                break
            else
                echo "$1 is not up on port $2"
                sleep 1
            fi
        done
    else
        echo "\$1 === service name"
        echo "\$2 === port"
    fi
}
list_connections() {
    sudo netstat -tulpn
}
whats_my_ip_mac() {
    ifconfig -a | grep inet
}
whats_my_ip_external() {
    curl -s http://ipecho.net/plain

}
whats_my_ip_external_a() {
    curl http://ipinfo.io
}
list_my_ips() {
    ip r
}
whats_my_ip() {
    hostname -I | cut -d' ' -f1
}
whats_my_network_interface() {
    ip a | grep $(whats_my_ip)
}
