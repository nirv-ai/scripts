# Mount secrets engines
path "sys/mounts/*" {
  capabilities = [ "read", "update", "list" ]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = [ "read", "list" ]
}

# Write ACL policies
path "sys/policies/acl/*" {
  capabilities = [  "read", "update", "list" ]
}

# Manage tokens for verification
path "auth/token/create" {
  capabilities = [  "read", "update", "list" ]
}
