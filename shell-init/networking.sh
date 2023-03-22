#!/usr/bin/env bash

cmd_time() {
  time "$@"
}
export -f cmd_time

get_hosts() {
  getent hosts
}
export -f get_hosts

get_port_status() {
  nc -z 127.0.0.1 ${1:?port number required} && echo "IN USE" || echo "FREE"
}
export -f get_port_status

get_networks() {
  getent networks
}
export -f get_networks

get_response_headers() {
  if [[ $# -eq 1 ]]; then
    curl -I "$1"
  else
    echo "\$1 === url"
  fi
}
export -f get_response_headers

get_response_time() {
  if [[ $# -eq 1 ]]; then
    cmd_time get_response_headers "$1"
  else
    echo "\$1 === url"
  fi
}
export -f get_response_time

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
export -f do_response_dos

list_open_ports() {
  nmap ${1:?ip addr/localhost required}
}
export -f list_open_ports

list_connections() {
  sudo netstat -tulpn
}
export -f list_connections

list_listeners() {
  netstat -lt
  # ss -ltnp
}
export -f list_listeners

whats_my_ip_mac() {
  ifconfig -a | grep inet
}
export -f whats_my_ip_mac

whats_my_ip_external() {
  curl -s http://ipecho.net/plain

}
export -f whats_my_ip_external

whats_my_ip_external_a() {
  curl http://ipinfo.io
}
export -f whats_my_ip_external_a

list_my_ips() {
  ip r
}
export -f list_my_ips

whats_my_ip() {
  hostname -I | cut -d' ' -f1
}
export -f whats_my_ip

whats_my_network_interface() {
  ip a | grep $(whats_my_ip)
}
export -f whats_my_network_interface
