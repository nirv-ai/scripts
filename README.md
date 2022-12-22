# NIRVAI SCRIPTS

- useful scripts
- additional readme coming soon

## TLDR

- many of the scripts rely on shell fns [within this public repo](https://github.com/noahehall/theBookOfNoah/tree/master/linux/bash_cli_fns)
- you can setup your shell to be l33t like me by [sourcing this file](https://github.com/noahehall/theBookOfNoah/blob/master/linux/_sourceme_.sh) in the parent directory

## script.nmd.sh

- actively used for running nomad jobs

```sh
################# help links
#########
# @see https://github.com/hashicorp/nomad
# @see https://discuss.hashicorp.com/t/failed-to-find-plugin-bridge-in-path/3095
## ^ need to enable cni plugin
# @see https://developer.hashicorp.com/nomad/docs/drivers/docker#enabled-1
## ^ need to enable bind mounts
# @see https://developer.hashicorp.com/nomad/docs/drivers/docker#allow_caps
## ^ for vault you need to enable cap_add ipc_lock
## ^ for debugging set it to "all"
# @see registry.sh
## ^ Failed to find docker auth
#########

#########
# FYI
# the UI is available at http://localhost:4646
# nomad doesnt work well with docker desktop, remove it
#########

################# basic workflow

# get docker export
docker compose build
docker compose convert | yq -r -o=json >.env.${ENV}.compose.json
# now symlink the .json file to wherever you run nomad cmds
# symlink this file to the same place
## prefix all cmds with ./script.nmd.sh poop poop poop
## poop being one of the below

# check on the server
get status team
get status all

# creating stuff
create gossipkey
create job myJobName
get plan myJobName # provides indexNumber

# running stuff
run myJobName indexNumber

# restarting stuff
restart loc allocationId taskName # todo: https://developer.hashicorp.com/nomad/docs/commands/alloc/restart

# execing stuff
exec loc  allocationId cmd .... @ todo https://developer.hashicorp.com/nomad/docs/commands/alloc/exec

# checking on running/failing stuff
get status node # see nodes and there ids
get status node nodeId # provding nodeId is super helpful; also provides allocationId
get status loc allocationId # super helpful for checking on failed jobs, provides deployment id
get status dep deploymentId # super helpful
get logs jobName deploymentId

# stopping stuff
stop job myJobName
rm myJobName # this purges the job
system gc # todo: nomad system gc # this is your fkn friend

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
