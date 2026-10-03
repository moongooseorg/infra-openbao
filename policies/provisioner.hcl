path "sys/policies/acl/*" {
    capabilities = ["create", "read", "update", "delete"]
}

path "auth/approle/role/*" {
    capabilities = ["create", "read", "update", "delete"]
}

path "auth/approle/role/*/role-id" {
    capabilities = ["read"]
}

path "auth/approle/role/*/secret-id" {
    capabilities = ["create", "update"]
}

path "kv/data/*" {
    capabilities = ["create"]
}

path "kv/metadata/*" {
    capabilities = ["read", "delete"]
}
