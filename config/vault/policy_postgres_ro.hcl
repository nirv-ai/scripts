########################
# @see https://developer.hashicorp.com/vault/tutorials/db-credentials/database-secrets
# core-postgres: postgresql://{{username}}:{{password}}@static-container-name:static-container-port/static-db-name?sslmode=disable
########################

#############
## RO
#############
# Get credentials from the database secrets engine 'readonly' role.
path "database/creds/readonly" {
  capabilities = [ "read" ]
}
