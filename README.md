# docker-config

### Initial Setup
Just perform a github build and deploy action

### how to setup a new approle
## Create the secret path
create a secret at path `<your app name>`

## Policy creation
navigate to policies -> acl policies
create a policy called `<your app name>`
with the contents
```
path "kv/data/<your app name>" {
    capabilities = ["read"]
}
```

## Role creation
open the terminal (top left corner)

enter the following commands
```
write auth/approle/role/<your app name> token_policies=<your app name> token_ttl=20m token_max_ttl=1h secret_id_ttl=0 secret_id_num_uses=0

read auth/approle/role/<your app name>/role-id

write -f auth/approle/role/<your app name>/secret-id
```

Be sure to copy the secret id to your github secrets immediately