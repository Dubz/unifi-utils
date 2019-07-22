#!/bin/bash

# This requires identities to be set up in ~/.ssh/config

# Enter your controller information here
CONTROLLER_HOST=unifi.example.com
CONTROLLER_USER=ubnt

# Local path to LetsEncrypt files
CERTBOT_LOCAL_DIR_WORK=~/ssl/letsencrypt/lib
CERTBOT_LOCAL_DIR_LOGS=~/ssl/letsencrypt/log
CERTBOT_LOCAL_DIR_CONFIG=~/ssl/letsencrypt/ssl

# Optional
# If using a remote server to obtain certificates, and not done directly on this machine
CERTBOT_USE_EXTERNAL=false
CERTBOT_EXTERNAL_HOST=api.example.com
CERTBOT_EXTERNAL_USER=certbot-example_com
CERTBOT_EXTERNAL_DIR_WORK=/var/lib/letsencrypt
CERTBOT_EXTERNAL_DIR_LOGS=/var/log/letsencrypt
CERTBOT_EXTERNAL_DIR_CONFIG=/etc/letsencrypt


# Clone from external server to local server (if used)
if [ "$CERTBOT_USE_EXTERNAL" = "true" ]; then
    echo -n "Pulling contents from remote server..."
    # Make the local paths if needed
    mkdir --parents "$CERTBOT_LOCAL_DIR_WORK/"
    mkdir --parents "$CERTBOT_LOCAL_DIR_LOGS/"
    mkdir --parents "$CERTBOT_LOCAL_DIR_CONFIG/"
    rsync -qrzl -e 'ssh -q' --delete $CERTBOT_EXTERNAL_USER@$CERTBOT_EXTERNAL_HOST:"$CERTBOT_EXTERNAL_DIR_WORK/" "$CERTBOT_LOCAL_DIR_WORK"
    rsync -qrzl -e 'ssh -q' --delete $CERTBOT_EXTERNAL_USER@$CERTBOT_EXTERNAL_HOST:"$CERTBOT_EXTERNAL_DIR_LOGS/" "$CERTBOT_LOCAL_DIR_LOGS"
    rsync -qrzl -e 'ssh -q' --delete $CERTBOT_EXTERNAL_USER@$CERTBOT_EXTERNAL_HOST:"$CERTBOT_EXTERNAL_DIR_CONFIG/" "$CERTBOT_LOCAL_DIR_CONFIG"
    echo "done!"
fi


# Are the required cert files there?
for f in cert.pem fullchain.pem privkey.pem
do
    if [ ! -f "$CERTBOT_LOCAL_DIR_CONFIG/live/$CONTROLLER_HOST/$f" ]; then
        echo "Missing file: $f - aborting!"
        exit 1
    fi
done

# Check integrity and for any changes/differences, before doing anything on the CloudKey
# We'll check all 3 just because, even though we're only using 2 of them
echo -n "Checking certificate integrity..."
md5_cert=$(openssl x509 -noout -modulus -in "$CERTBOT_LOCAL_DIR_CONFIG/live/$CONTROLLER_HOST/cert.pem" | openssl md5)
md5_fullchain=$(openssl x509 -noout -modulus -in "$CERTBOT_LOCAL_DIR_CONFIG/live/$CONTROLLER_HOST/fullchain.pem" | openssl md5)
md5_privkey=$(openssl rsa -noout -modulus -in "$CERTBOT_LOCAL_DIR_CONFIG/live/$CONTROLLER_HOST/privkey.pem" | openssl md5)
if [ "$md5_privkey" != "$md5_cert" ]; then
    echo "Private key and cert do not match!"
    exit 1
elif [ "$md5_privkey" != "$md5_fullchain" ]; then
    echo "Private key and full chain do not match!"
    exit 1
else
    echo "integrity passed!"
fi

# Backup original keys on CK
echo -n "Creating backups of cloudkey.key and cloudkey.crt on controller..."
ssh $CONTROLLER_USER@$CONTROLLER_HOST 'for f in {cloudkey.key,cloudkey.crt}; do cp -n "/etc/ssl/private/$f" "/etc/ssl/private/$f.bak"; done'
echo "done!"

# Copy to CK
echo -n "Copying files to controller..."
scp -q "$CERTBOT_LOCAL_DIR_CONFIG/live/$CONTROLLER_HOST/fullchain.pem" $CONTROLLER_USER@$CONTROLLER_HOST:"/etc/ssl/private/cloudkey.crt"
scp -q "$CERTBOT_LOCAL_DIR_CONFIG/live/$CONTROLLER_HOST/privkey.pem" $CONTROLLER_USER@$CONTROLLER_HOST:"/etc/ssl/private/cloudkey.key"
echo "done!"

# Reload nginx on the Cloud Key
echo -n "Reloading nginx..."
ssh $CONTROLLER_USER@$CONTROLLER_HOST 'nginx -s reload'
echo "done!"

# Done!
echo "Process completed!"
exit 0
