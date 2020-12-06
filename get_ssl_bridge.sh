#!/bin/sh

# unifi-utils
# get_ssl_bridge.sh
# Utilities used to automate tasks with UniFi setups
# by Dubz <https://github.com/Dubz>
# from unifi-utils <https://github.com/Dubz/unifi-utils>
# Version 2.0-dev
# Last Updated December 05, 2020

# REQUIREMENTS
# 1) Assumes you already have a valid SSL certificate
# 2) ./config-default file copied to ./config and edited as necessary
# 3) Identities to be set up in ~/.ssh/config as needed

# KEYSTORE BACKUP
# Even though this script attempts to be clever and careful in how it backs up your existing keystore,
# it's never a bad idea to manually back up your keystore (located at $UNIFI_DIR/data/keystore on RedHat
# systems or /$UNIFI_DIR/keystore on Debian/Ubuntu systems) to a separate directory before running this
# script. If anything goes wrong, you can restore from your backup, restart the UniFi Controller service,
# and be back online immediately.


# Load the config file
if [ -z "${CONFIG_LOADED+x}" ]; then
    if [ ! -s "config" ]; then
        echo "CONFIG FILE NOT FOUND!"
        echo -n "Copying config-default to config..."
        cp "./config-default" "./config"
        echo "done!"
    fi
    source config
    if [ "${CONFIG_IS_DEFAULT}" ]; then
        echo "Please configure your settings by editing the config file."
        return
        exit 1
    fi
fi

# Load the default vars
if [ -z "${DEFAULT_SSL_LOCATION+x}" ]; then
    source vars.sh
fi

# Load the necessary functions
if [ ! typeset -f check_file_exist > /dev/null ]; then
    source func.sh
fi

# Clone from external server to local server (if used)
if [ "${CERTBOT_USE_EXTERNAL}" == "true" ] && [ "${BRIDGE_SYNCED}" != "true" ]; then
    # Make the local paths if needed
    if [[ ! -d "${CERTBOT_LOCAL_DIR_WORK}/" ]]; then
        mkdir --parents "${CERTBOT_LOCAL_DIR_WORK}/"
        echo "Made local work directory: ${CERTBOT_LOCAL_DIR_WORK}/"
    fi
    if [[ ! -d "${CERTBOT_LOCAL_DIR_LOGS}/" ]]; then
        mkdir --parents "${CERTBOT_LOCAL_DIR_LOGS}/"
        echo "Made local logs directory: ${CERTBOT_LOCAL_DIR_LOGS}/"
    fi
    if [[ ! -d "${CERTBOT_LOCAL_DIR_CONFIG}/" ]]; then
        mkdir --parents "${CERTBOT_LOCAL_DIR_CONFIG}/"
        echo "Made local config directory: ${CERTBOT_LOCAL_DIR_CONFIG}/"
    fi
    echo -n "Pulling contents from remote server..."
    rsync -qrzl -e 'ssh -q -o "VerifyHostKeyDNS=yes"' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_WORK}/" "${CERTBOT_LOCAL_DIR_WORK}"
    rsync -qrzl -e 'ssh -q -o "VerifyHostKeyDNS=yes"' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_LOGS}/" "${CERTBOT_LOCAL_DIR_LOGS}"
    rsync -qrzl -e 'ssh -q -o "VerifyHostKeyDNS=yes"' --delete ${CERTBOT_EXTERNAL_USER}@${CERTBOT_EXTERNAL_HOST}:"${CERTBOT_EXTERNAL_DIR_CONFIG}/" "${CERTBOT_LOCAL_DIR_CONFIG}"
    echo "done!"
    # So we don't do this every time
    BRIDGE_SYNCED=true
fi
