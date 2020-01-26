source ./dap.config

set -euo pipefail

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
    -h $CONJUR_MASTER_HOST_NAME \
    -p $CONJUR_ADMIN_PASSWORD \
    --master-altnames "$MASTER_ALTNAMES" \
	--follower-altnames "$FOLLOWER_ALTNAMES" \
    $CONJUR_ACCOUNT

#extraer el certificado 
docker cp -L $CONJUR_MASTER_CONTAINER_NAME:/opt/conjur/etc/ssl/conjur.pem conjur-master-$CONJUR_ACCOUNT.pem

# obtener la semilla para instalar el follower
docker exec $CONJUR_MASTER_CONTAINER_NAME evoke seed follower conjur-follower > follower-seed.tar


