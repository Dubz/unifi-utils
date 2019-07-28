#!/bin/sh

# unifi-utils
# controller_update_ssl.sh
# UniFi Controller SSL Certificate update script for Unix/Linux Systems
# by Dubz <https://github.com/Dubz>
# from unifi-utils <https://github.com/Dubz/unifi-utils>
# Incorporates ideas from https://github.com/stevejenkins/ubnt-linux-utils/unifi_ssl_import.sh
# Incorporates ideas from https://source.sosdg.org/brielle/lets-encrypt-scripts
# Version 0.3
# Last Updated July 27, 2019

# REQUIREMENTS
# 1) Assumes you already have a valid SSL certificate
# 2) ./config-default file copied to ./config and edited as necessary
# 3) Identities to be set up in ~/.ssh/config as needed

# KEYSTORE BACKUP
# Even though this script attempts to be clever and careful in how it backs up your existing keystore,
# it's never a bad idea to manually back up your keystore (located at $UNIFI_DIR/data/keystore on RedHat
# systems or /$UNIFI_DIR/keystore on Debian/Ubunty systems) to a separate directory before running this
# script. If anything goes wrong, you can restore from your backup, restart the UniFi Controller service,
# and be back online immediately.


# Load the config file
if [ -z "${CONFIG_LOADED+x}" ]; then
    if [ ! -s "config" ]; then
        echo "CONFIG FILE NOT FOUND!"
        echo -n "Copying config-default to config..."
        cp "./config-default" "./config"
        echo "done!"
        echo "Please configure your settings by editing the config file"
        exit 1
    fi
    source config
fi

# Clone from external server to local server (if used)
if [ "${CERTBOT_USE_EXTERNAL}" == "true" ] && [ "${BRIDGE_SYNCED}" != "true" ]; then
    echo -n "Pulling contents from remote server..."
    # Make the local paths if needed
    mkdir --parents "${CERTBOT_LOCAL_DIR_WORK}/"
    mkdir --parents "${CERTBOT_LOCAL_DIR_LOGS}/"
    mkdir --parents "${CERTBOT_LOCAL_DIR_CONFIG}/"
    rsync -qrzl -e 'ssh -q' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_WORK}/" "${CERTBOT_LOCAL_DIR_WORK}"
    rsync -qrzl -e 'ssh -q' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_LOGS}/" "${CERTBOT_LOCAL_DIR_LOGS}"
    rsync -qrzl -e 'ssh -q' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_CONFIG}/" "${CERTBOT_LOCAL_DIR_CONFIG}"
    echo "done!"
    # So we don't do this every time
    BRIDGE_SYNCED=true
fi