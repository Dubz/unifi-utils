#!/bin/bash

# unifi_ssl_cron.sh
# UniFi Controller SSL Certificate Cron Script for Unix/Linux Systems
# by Dubz <https://github.com/Dubz>
# Incorporates ideas from https://github.com/stevejenkins/ubnt-linux-utils/unifi_ssl_import.sh
# Incorporates ideas from https://source.sosdg.org/brielle/lets-encrypt-scripts
# Version 0.2
# Last Updated July 22, 2019

# REQUIREMENTS
# 1) Assumes you already have a valid LetsEncrypt certbot running
# 2) Identities to be set up in ~/.ssh/config

# KEYSTORE BACKUP
# Even though this script attempts to be clever and careful in how it backs up your existing keystore,
# it's never a bad idea to manually back up your keystore (located at $UNIFI_DIR/data/keystore on RedHat
# systems or /$UNIFI_DIR/keystore on Debian/Ubunty systems) to a separate directory before running this
# script. If anything goes wrong, you can restore from your backup, restart the UniFi Controller service,
# and be back online immediately.


# Enter your controller information here
CONTROLLER_HOST=unifi.example.com
CONTROLLER_USER=ubnt

# Local path to LetsEncrypt files
CERTBOT_LOCAL_DIR_WORK=~/ssl/letsencrypt/lib
CERTBOT_LOCAL_DIR_LOGS=~/ssl/letsencrypt/log
CERTBOT_LOCAL_DIR_CONFIG=~/ssl/letsencrypt/ssl
# Local path for worker to store data
CERTBOT_LOCAL_DIR_CACHE=~/ssl/letsencrypt/cache

UNIFI_SERVICE=unifi

# Uncomment following three lines for Fedora/RedHat/CentOS
#UNIFI_DIR=/opt/UniFi
#JAVA_DIR=${UNIFI_DIR}
#KEYSTORE=${UNIFI_DIR}/data/keystore

# Uncomment following three lines for Debian/Ubuntu
#UNIFI_DIR=/var/lib/unifi
#JAVA_DIR=/usr/lib/unifi
#KEYSTORE=${UNIFI_DIR}/keystore

# Uncomment following three lines for CloudKey
UNIFI_DIR=/var/lib/unifi
JAVA_DIR=/usr/lib/unifi
KEYSTORE=${JAVA_DIR}/data/keystore

# Optional
# If using a remote server to obtain certificates, and not done directly on this machine
CERTBOT_USE_EXTERNAL=false
CERTBOT_EXTERNAL_HOST=api.example.com
CERTBOT_EXTERNAL_USER=certbot-example_com
CERTBOT_EXTERNAL_DIR_WORK=/var/lib/letsencrypt
CERTBOT_EXTERNAL_DIR_LOGS=/var/log/letsencrypt
CERTBOT_EXTERNAL_DIR_CONFIG=/etc/letsencrypt

# CONFIGURATION OPTIONS YOU PROBABLY SHOULDN'T CHANGE
ALIAS=unifi
PASSWORD=aircontrolenterprise


# Clone from external server to local server (if used)
if [ "${CERTBOT_USE_EXTERNAL}" = "true" ]; then
    echo -n "Pulling contents from remote server..."
    # Make the local paths if needed
    mkdir --parents "${CERTBOT_LOCAL_DIR_WORK}/"
    mkdir --parents "${CERTBOT_LOCAL_DIR_LOGS}/"
    mkdir --parents "${CERTBOT_LOCAL_DIR_CONFIG}/"
    rsync -qrzl -e 'ssh -q' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_WORK}/" "${CERTBOT_LOCAL_DIR_WORK}"
    rsync -qrzl -e 'ssh -q' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_LOGS}/" "${CERTBOT_LOCAL_DIR_LOGS}"
    rsync -qrzl -e 'ssh -q' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_CONFIG}/" "${CERTBOT_LOCAL_DIR_CONFIG}"
    echo "done!"
fi


# Are the required cert files there?
for f in cert.pem fullchain.pem privkey.pem
do
    if [ ! -f "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/${f}" ]; then
        echo "Missing file: ${f} - aborting!"
        exit 1
    fi
done

# Create cache directory/file if not existing
if [ ! -f "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512" ]; then
    if [ ! -d "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/" ]; then
        mkdir --parents "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/"
    fi
    touch "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512"
fi

# Check integrity and for any changes/differences, before doing anything on the CloudKey
# We'll check all 3 just because, even though we're only using 2 of them
echo -n "Checking certificate integrity..."
sha512_cert=$(openssl x509 -noout -modulus -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/cert.pem" | openssl sha512)
sha512_fullchain=$(openssl x509 -noout -modulus -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/fullchain.pem" | openssl sha512)
sha512_privkey=$(openssl rsa -noout -modulus -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/privkey.pem" | openssl sha512)
sha512_last=$(<"${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512")
if [ "${sha512_privkey}" != "${sha512_cert}" ]; then
    echo "Private key and cert do not match!"
    exit 1
elif [ "${sha512_privkey}" != "${sha512_fullchain}" ]; then
    echo "Private key and full chain do not match!"
    exit 1
else
    echo "integrity passed!"
    # Did the keys change? If not, no sense in continuing...
    if [ "${sha512_privkey}" == "${sha512_last}" ]; then
        echo "Keys did not change, stopping!"
        exit 0
    fi
fi


# Convert cert to PKCS12 format
echo -n "Exporting SSL certificate and key data into temporary PKCS12 file..."
openssl pkcs12 -export \
    -inkey "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/privkey.pem" \
    -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/fullchain.pem" \
    -out "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/fullchain.p12" \
    -name ${ALIAS} \
    -passout pass:${PASSWORD}
echo "done!"


# Everything is prepped, time to interact with the CloudKey!


# Backups backups backups!

# Backup original keystore on CK
echo -n "Creating backup of keystore on controller..."
# ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "if [ -s \"${KEYSTORE}.orig\" ]; then cp -n \"${KEYSTORE}\" \"${KEYSTORE}.orig\"; else cp -n \"${KEYSTORE}\" \"${KEYSTORE}.bak\"; fi"
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "if [ -s \"${KEYSTORE}.orig\" ]; then echo -n \"Backup of original keystore exists! Creating non-destructive backup as keystore.bak...\"; cp -n \"${KEYSTORE}\" \"${KEYSTORE}.bak\"; else echo -n \"no original keystore backup found. Creating backup as keystore.orig...\"; cp -n \"${KEYSTORE}\" \"${KEYSTORE}.orig\"; fi"
echo "done!"

# Backup original keys on CK
echo -n "Creating backups of cloudkey.key and cloudkey.crt on controller..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} 'for f in {cloudkey.key,cloudkey.crt}; do cp -n "/etc/ssl/private/$f" "/etc/ssl/private/$f.bak"; done'
echo "done!"


# Copy over...

# Copy to CK
echo -n "Copying files to controller..."
scp -q "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/fullchain.pem" $CONTROLLER_USER@${CONTROLLER_HOST}:"/etc/ssl/private/cloudkey.crt"
scp -q "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/privkey.pem" $CONTROLLER_USER@${CONTROLLER_HOST}:"/etc/ssl/private/cloudkey.key"
scp -q "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/fullchain.p12" $CONTROLLER_USER@${CONTROLLER_HOST}:"${JAVA_DIR}/data/fullchain.p12"
echo "done!"


# Stop service...
echo -n "Stopping UniFi Controller..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service ${UNIFI_SERVICE} stop"
echo "done!"


# Load keystore changes
echo -n "Removing previous certificate data from UniFi keystore..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "keytool -delete -alias ${ALIAS} -keystore ${KEYSTORE} -deststorepass ${PASSWORD}"
echo "done!"
echo -n "Importing SSL certificate into UniFi keystore..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "keytool -importkeystore \
    -srckeystore \"${JAVA_DIR}/data/fullchain.p12\" \
    -srcstoretype PKCS12 \
    -srcstorepass ${PASSWORD} \
    -destkeystore ${KEYSTORE} \
    -deststorepass ${PASSWORD} \
    -destkeypass ${PASSWORD} \
    -alias ${ALIAS} \
    -trustcacerts"
echo "done!"


# Reload...
# Start service back up
echo -n "Restarting UniFi Controller to apply new Let's Encrypt SSL certificate..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service ${UNIFI_SERVICE} start"
echo "done!"

# Reload nginx on the Cloud Key
echo -n "Reloading nginx..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} 'nginx -s reload'
echo "done!"


echo -n "Cleaning up CloudKey..."
ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} 'rm -f "${JAVA_DIR}/data/fullchain.p12"'
echo "done!"

# Save the new key hash to the cache for next run
echo -n "Caching cert hash..."
echo ${sha512_privkey} > "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512"
# Log for reference
echo ${sha512_privkey} >> "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512.log"
echo "done!"


# Done!
echo "Process completed!"
exit 0