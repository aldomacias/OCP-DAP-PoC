
## master options

export CONJUR_MASTER_HOST_NAME=dap.amac.lab
export CONJUR_APPLIANCE_IMAGE=registry.tld/conjur-appliance:11.2.1
export CONJUR_MASTER_CONTAINER_NAME=dap
export CONJUR_ADMIN_PASSWORD=Cyberark1
export CONJUR_ACCOUNT=dev

#OCP Variables
export OC_FOLLOWER_PROJECT=cyberark
export OC_CONJUR_SVC_ACCT=conjur-cluster
export OC_FOLLOWER_APP_LABEL=conjur-follower
export OC_FOLLOWER_EXT_FQDN=follower.ocp.amac.lab

export MASTER_ALTNAMES="$CONJUR_MASTER_HOST_NAME"
export CONJUR_FOLLOWER_SERVICE_NAME=conjur-follower.$OC_FOLLOWER_PROJECT.svc.cluster.local
export FOLLOWER_ALTNAMES="$CONJUR_MASTER_HOST_NAME,$CONJUR_FOLLOWER_SERVICE_NAME"
export AUTHENTICATOR_ID=dev


export CLI_IMAGE_NAME=conjurinc/cli5:latest
