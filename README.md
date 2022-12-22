# NIRVAI SCRIPTS

- useful scripts
- additional readme coming soon

## TLDR

- many of the scripts rely on shell fns [within this public repo](https://github.com/noahehall/theBookOfNoah/tree/master/linux/bash_cli_fns)
- you can setup your shell to be l33t like me by [sourcing this file](https://github.com/noahehall/theBookOfNoah/blob/master/linux/_sourceme_.sh) in the parent directory

## script.nmd.sh

- actively used for running nomad jobs

```sh

################# basic workflow
docker compose build
docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
# now symlink the .json file to wherever you run nomad cmds
# symlink this file to the same place
## prefix all cmds with ./script.nmd.sh poop poop poop
## poop being one of the below
create job myJobName
get plan myJobName
run job myJobName
stop job myJobName
rm myJobName

```

## script.vault.sh

- actively used for interacting with a tls vault server behind a tls proxy
- useful for:
  - verifying vault http endpoints from the CLI
  - interacting with vault without execing into a container or opening a browser
- ENV requirements
  - `export VAULT_ADDR=https://your.vault.addr:and_port`
  - `export VAULT_TOKEN=your_vault_token`
    - can be set to an empty string if you dont have one yet

```sh
# usage
./script.vault.sh cmd

## cmds
### enable a secret engine e.g. kv-v2
enable secret secretEngineType

### enable approle engine e.g. approle
enable approle approleType

### list all approles
list approles

### list enabled secrets engines
list secret-engines

### list provisioned keys for a postgres role
list postgres leases dbRoleName

### create a secret-id for roleName
create approle-secret roleName

### upsert approle appRoleName with a list of attached policies
create approle appRoleName pol1,polX

### create kv2 secret(s) at secretPath
#### dont prepend `secret/` to secretPath
#### e.g. create secret kv2 poo/in/ur/eye '{"a": "b", "c": "d"}'
create secret kv2 secretPath jsonString

### get dynamic postgres creds for database role dbRoleName
get postgres creds dbRoleName

### get the secret (kv-v2) at the given path, e.g. foo
#### dont prepend `secret/` to path
get secret secretPath

### get the status (sys/healthb) of the vault server
get status

### get vault credentials for an approle
get creds roleId secretId

### get all properties associated with an approle
get approle info appRoleName

### get the approle role_id for roleName
get approle id appRoleName

### get the openapi spec for some path
help some/path/

```
