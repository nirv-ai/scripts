########################
# @see https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets
# core-postgres: postgresql://{{username}}:{{password}}@static-container-name:static-container-port/static-db-name?sslmode=disable
########################

#############
## RW
#############
# Get credentials from the database secrets engine 'readwrite' role.
path "database/creds/readwrite" {
  capabilities = [ "read" ]
}
