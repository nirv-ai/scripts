# you should have more eyeballs than vault admins
path "secret/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo"]
}

path "sys/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

path "auth/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

path "database/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}

path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
