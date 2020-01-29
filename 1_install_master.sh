source ./config.sh

set -x

# ejecutar el contenedor de conjur
docker run -d \
    --name $CONJUR_MASTER_CONTAINER_NAME \
    -p "443:443" \
    -p "5432:5432" \
    -p "1999:1999" \
    --restart always \
    --security-opt seccomp:unconfined \
    $CONJUR_APPLIANCE_IMAGE 


#inicializar conjur
echo "Configuring Conjur master..."
docker exec $CONJUR_MASTER_CONTAINER_NAME \
    evoke configure master     \
    --accept-eula \
    -h $CONJUR_MASTER_HOST_NAME \
    -p $CONJUR_ADMIN_PASSWORD \
    --master-altnames "$MASTER_ALTNAMES" \
	--follower-altnames "$FOLLOWER_ALTNAMES" \
    $CONJUR_ACCOUNT

#extraer el certificado de master
docker cp -L $CONJUR_MASTER_CONTAINER_NAME:/opt/conjur/etc/ssl/conjur.pem conjur-master-$CONJUR_ACCOUNT.pem

# generar un certificado para el follower 
docker exec $CONJUR_MASTER_CONTAINER_NAME evoke ca issue --force \
    $OC_FOLLOWER_EXT_FQDN conjur-follower.$OC_FOLLOWER_PROJECT.svc.cluster.local

# obtener la semilla para instalar el follower
docker exec $CONJUR_MASTER_CONTAINER_NAME evoke seed follower $OC_FOLLOWER_EXT_FQDN > follower-seed.tar

# prepare policy file for authenticators
cat "./kubernetes-followers-template.yml" | \
  sed -e "s#{{ OC_FOLLOWER_PROJECT }}#$OC_FOLLOWER_PROJECT#g"  | \
  sed -e "s#{{ OC_CONJUR_SVC_ACCT }}#$OC_CONJUR_SVC_ACCT#g"  | \
  > ./policy/kubernetes-followers.yml

read -p "\n==== Review root.yml before moving on to the next step and press enter to continue ====\n"

#authenticate to conjur with admin
api_key=$(curl -sk --user admin:$CONJUR_ADMIN_PASSWORD https://$CONJUR_MASTER_HOST_NAME/authn/$CONJUR_ACCOUNT/login)
auth_result=$(curl -sk https://$CONJUR_MASTER_HOST_NAME/authn/$CONJUR_ACCOUNT/$CONJUR_USER/authenticate -d "$api_key")

DAP_TOKEN=$(echo -n $auth_result | base64 | tr -d '\r\n')
DAP_AUTH_HEADER="Authorization: Token token=\"$DAP_TOKEN\""

# load policy for authenticators/followers
POST_URL="https://$CONJUR_MASTER_HOST_NAME/policies/$CONJUR_ACCOUNT/policy/root"
curl -sk -H "$DAP_AUTH_HEADER" -d "$(< ./policy/kubernetes-followers.yml)" $POST_URL

# initialize CA

docker exec $CONJUR_MASTER_CONTAINER_NAME \
    chpst -u conjur conjur-plugin-service possum \
      rake authn_k8s:ca_init["conjur/authn-k8s/$AUTHENTICATOR_ID"] >& /dev/null

#enable Authenticator

docker exec $CONJUR_MASTER_CONTAINER_NAME bash -c \
    "echo CONJUR_AUTHENTICATORS=\"authn,authn-k8s/$AUTHENTICATOR_ID\" >> \
      /opt/conjur/etc/conjur.conf && \
        sv restart conjur"

echo "==== Enabled DAP Authenticators ===="
curl -sk https://$CONJUR_MASTER_CONTAINER_NAME/info | jq '.authenticators.enabled'