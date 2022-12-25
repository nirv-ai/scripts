# read own secrets
path "secret/data/bff" {
  capabilities = [ "read"]
}
path "secret/data/bff/*" {
  capabilities = [ "read" ]
}

# get postgres secrets
path "database/creds/read*" {
  capabilities = ["read"]
}
