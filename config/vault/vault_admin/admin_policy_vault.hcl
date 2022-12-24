path "secret/*" {
  capabilities = [ "create", "read", "update", "delete", "list"]
}

path "sys/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "auth/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "database/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
