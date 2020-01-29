#!/bin/bash
set -x

. ./config.sh

set -x

# prepare yaml for creation of Project/ClusterRole/ServiceAccount

sed -e "s#{{ OC_FOLLOWER_PROJECT }}#$OC_FOLLOWER_PROJECT#g" "./templates/openshift/conjur-role-template.yml" | \
sed -e "s#{{ OC_CONJUR_SVC_ACCT }}#$OC_CONJUR_SVC_ACCT#g"  | \
sed -e "s#{{ OC_FOLLOWER_APP_LABEL }}#$OC_FOLLOWER_APP_LABEL#g" \
> ./policy/openshift/conjur-role.yml 

# creation of Project/ClusterRole/ServiceAccount
oc create -f ./policy/openshift/conjur-role.yml
oc config set-context $(oc config current-context) --namespace=$OC_FOLLOWER_PROJECT

# get the certificate of the dap master 
echo -n | openssl s_client \
    -showcerts \
    -connect $CONJUR_MASTER_HOST_NAME:443 \
    | sed -ne '/-BEGIN CERTIFICATE-/,/-END CERTIFICATE-/p' \
    > ./conjur-cert.pem

# create configmap with the dap-master certificate
oc create configmap server-certificate \
    --from-file=ssl-certificate=./conjur-cert.pem

##### configure Openshift RBAC ####
echo "Configuring OpenShift admin permissions."
  
# allow pods with conjur-cluster serviceaccount to run as root

oc adm policy add-scc-to-user anyuid "system:serviceaccount:$OC_FOLLOWER_PROJECT:$OC_CONJUR_SVC_ACCT"

# add permissions for Follower admin user on registry, default namespace & Follower namespaces
oc adm policy add-role-to-user system:registry $FOLLOWER_ADMIN_USERNAME
oc adm policy add-role-to-user system:image-builder $FOLLOWER_ADMIN_USERNAME
oc adm policy add-role-to-user admin $FOLLOWER_ADMIN_USERNAME -n default
oc adm policy add-role-to-user admin $FOLLOWER_ADMIN_USERNAME -n $OC_FOLLOWER_PROJECT

##### getting information from OC to store in dap master #######
TOKEN_SECRET_NAME="$(oc get secrets -n $OC_FOLLOWER_PROJECT \
    | grep 'conjur.*service-account-token' \
    | head -n1 \
    | awk '{print $1}')"

OC_CA_CERT="$(oc get secret -n $OC_FOLLOWER_PROJECT $TOKEN_SECRET_NAME -o json \
      | jq -r '.data["ca.crt"]')"

OC_SVC_ACCT_TOKEN="$(oc get secret -n $OC_FOLLOWER_PROJECT $TOKEN_SECRET_NAME -o json \
      | jq -r .data.token)"

OC_API_URL="$(oc config view --minify -o json \
      | jq -r '.clusters[0].cluster.server')"

cat << EOF > ./oc_values.json
{
  "ca_cert": "$OC_CA_CERT",
  "svc_token": "$OC_SVC_ACCT_TOKEN",
  "api_url": "$OC_API_URL"
}
EOF

printf "\n\n==== Done collecting information. Information stored in ../oc_values.json ====\n"
printf "==== Please provide the ../oc_values.json values to the DAP Administrator ====\n\n"
