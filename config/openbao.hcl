ui = true
disable_mlock = true

seal "static" {
  current_key_id = "unseal-1"
  current_key    = "file:///openbao/secrets/unseal.key"
}

storage "raft" {
  path    = "/openbao/file"
  node_id = "homelab-1"
}

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/openbao/tls/bao.crt"
  tls_key_file  = "/openbao/tls/bao.key"
}
