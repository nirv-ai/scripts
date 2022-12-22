# NIRVAI SCRIPTS

- useful scripts for working within a monorepo, e.g. [turborepo](https://turbo.build/repo/docs)
- additional readme coming soon

## TLDR

- requires the following to be available
  - [JQ](https://stedolan.github.io/jq/)
  - [YQ](https://github.com/mikefarah/yq)
  - bash, or zsh/fish/etc set to `export bash=zsh`
    - moving to POSIX shell soon
  - each script requires the service it works with, e.g. registry.sh requires docker, vault requires vault, etc
- clone the repo and symlink the scripts to the root of your repo
  - some scripts are useful in the root of a specific app, e.g. nmd.sh should be wherever you execute nomad

## script.registry.sh

- actively used for working with a private docker registry on localhost

```sh
###################### READ FIRST
# @see [repo] https://github.com/distribution/distribution
# @see [docs] https://github.com/docker/docs/tree/main/registry
# @see https://www.marcusturewicz.com/blog/build-and-publish-docker-images-with-github-packages/
## @see https://docs.github.com/en/actions/publishing-packages/publishing-docker-images
######################

###################### FYI
# setup for a local registry for development
# but definitely recommend canceling disney plus (but keep netflix, just sayin)
# so you can afford $5 (...$7) private registry with docker hub
## from hub: You are expected to be familiar with systems
## availability and scalability, logging and log processing,
## systems monitoring, and security 101. Strong understanding
## of http and overall network communications,
## plus familiarity with golang are certainly useful
## as well for advanced operations or hacking.
######################

###################### setup your /etc/hosts
# e.g. to use a registry at dev.nirv.ai:5000
# add the following to /etc/hosts
127.0.0.1 dev.nirv.ai
# checkout /letencrypt dir for configuring a TLS cert pointed at dev.nirv.ai
######################


###################### interface
export REG_CERTS_PATH=apps/nirvai-core-letsencrypt/dev-nirv-ai
export REG_DOMAIN=nirv.ai
export REG_SUBD=dev
export REG_HOST_PORT=5000

## your registry will be available at dev.nirv.ai:5000
## will auto tag images to that registry
## will auto remove images sourced from hub to push to that registry
######################


##################### usage
## ensure the ENV vars are set
## its setup to point for local development at dev.nirv.ai
./script.registry.sh poop

> run: runs a registry
> reset: purges and restarts a registry
> tag: tags an image and pushes it to registry
> tag_running: tags the image of all running containers and pushes all to registry

```

## script.nmd.sh

- actively used for working with nomad
- requires you have a local docker registry setup, see registry.sh

```sh
###################### helpful links
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
######################

###################### FYI
# the UI is available at http://localhost:4646
# nomad doesnt work well with docker desktop, remove it
######################

###################### basic workflow
########### cd nirvai/core
# refresh containers and upsert env.compose.json & yaml
./script.refresh.compose.sh

# ensure you've completed steps in ./script.registry.sh (see above)
# start the registry and push all container images to local registry
# ./script.registry.sh run
# ./script.registry.sh tag_running


########### cd ./apps/nirvai-core-nomad/dev
# symlink the json & yaml files

###################### now you can operate nomad
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
####################### usage
./script.vault.sh poop poop poop

# enable a secret engine e.g. kv-v2
enable secret secretEngineType

# enable approle engine e.g. approle
enable approle approleType

# list all approles
list approles

# list enabled secrets engines
list secret-engines

# list provisioned keys for a postgres role
list postgres leases dbRoleName

# create a secret-id for roleName
create approle-secret roleName

# upsert approle appRoleName with a list of attached policies
create approle appRoleName pol1,polX

# create kv2 secret(s) at secretPath
# dont prepend `secret/` to secretPath
# e.g. create secret kv2 poo/in/ur/eye '{"a": "b", "c": "d"}'
create secret kv2 secretPath jsonString

# get dynamic postgres creds for database role dbRoleName
get postgres creds dbRoleName

# get the secret (kv-v2) at the given path, e.g. foo
# dont prepend `secret/` to path
get secret secretPath

# get the status (sys/healthb) of the vault server
get status

# get vault credentials for an approle
get creds roleId secretId

# get all properties associated with an approle
get approle info appRoleName

# get the approle role_id for roleName
get approle id appRoleName

# get the openapi spec for some path
help some/path/

```
