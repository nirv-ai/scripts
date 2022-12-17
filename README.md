# NIRVAI SCRIPTS

- useful scripts

## TLDR

- many of the scripts rely on shell fns [within this public repo](https://github.com/noahehall/theBookOfNoah/tree/master/linux/bash_cli_fns)
- you can setup your shell to be l33t like me by [sourcing this file](https://github.com/noahehall/theBookOfNoah/blob/master/linux/_sourceme_.sh) in the parent directory

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
### e.g. kv-v2
enable secret secretEngineType

### e.g. approle
enable approle approleType

### doesnt work, need to find the correct path
list-secrets

### create a secret-id for roleName
create approle-secret roleName

### create a new approle roleName with a list of attached policies
create approle roleName pol1,polX

### get dynamic postgres creds for database role roleName
get postgres creds dbRoleName

### get the secret (kv-v2) at the given path
get secret secret/poop

### get the status (sys/healthb) of the vault server
get status

### get vault credentials for an approle
get creds roleId secretId

### get the approle role_id for roleName
get approle id roleName

### get the openapi spec for some path
help some/path/

```
