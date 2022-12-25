# @see https://developer.hashicorp.com/vault/docs/configuration

default_lease_ttl = "7d"
default_max_request_duration = "30s"
disable_cahe = false
disable_mlock = false
enable_response_header_hostname = true
enable_response_header_raft_node_id = true
log_format= "json"
max_lease_ttl = "30d"
raw_storage_endpoint = false
ui = true # requires at least 1 listener stanza

storage "raft" {
  path    = "/vault/data"
  node_id = "node1"
}


# advertise the non-loopback interface
api_addr = "https://127.0.0.1:8300"
cluster_addr = "https://127.0.0.1:8301"

listener "tcp" {
  address = "0.0.0.0:8300" # provides access to vault UI
  tls_cert_file = "/etc/ssl/certs/live/dev.nirv.ai/fullchain.pem"
  tls_key_file = "/etc/ssl/certs/live/dev.nirv.ai/privkey.pem"
  tls_disable = false
}


############################# todo
# plugin_directory
# plugin_file_uid
# plugin_file_permissions
// telemetry {
//   statsite_address = "127.0.0.1:8125"
//   disable_hostname = true
// }
// seal "transit" { @see https://developer.hashicorp.com/vault/docs/configuration/seal/transit
// }
