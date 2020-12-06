#!/bin/sh

# unifi-utils
# update_ssl.sh
# Utilities used to automate tasks with UniFi setups
# by Dubz <https://github.com/Dubz>
# from unifi-utils <https://github.com/Dubz/unifi-utils>
# Version 2.0-dev
# Last Updated December 05, 2020

# REQUIREMENTS
# 1) Assumes you already have valid SSL certificates
# 2) ./config-default file copied to ./config and edited as necessary
# 3) Identities to be set up in ~/.ssh/config as needed

# KEYSTORE BACKUP
# Even though this script attempts to be clever and careful in how it backs up your existing keystore,
# it's never a bad idea to manually back up your keystore (located at $UNIFI_DIR/data/keystore on RedHat
# systems or /$UNIFI_DIR/keystore on Debian/Ubunty systems) to a separate directory before running this
# script. If anything goes wrong, you can restore from your backup, restart the UniFi Controller service,
# and be back online immediately.


if [ ! -s "config" ]; then
	echo "CONFIG FILE NOT FOUND!"
	echo -n "Copying config-default to config..."
	cp "./config-default" "./config"
	echo "done!"
	echo "Please configure your settings by editing the config file"
	exit 1
fi

# Load the config file
source config
if [ "${CONFIG_IS_DEFAULT}" ]; then
    echo "Please configure your settings by editing the config file."
    exit 1
fi

# Load the default vars
if [ -z "${DEFAULT_SSL_LOCATION+x}" ]; then
    source vars.sh
fi

# Load the necessary functions
if [ ! type check_file_exist &> /dev/null ]; then
    source func.sh
fi

# Installer for controller
if [ "${CERTBOT_RUN_CONTROLLER}" == "true" ]; then
	echo "Running update_ssl_controller.sh..."
	source update_ssl_controller.sh
	echo "Controller SSL udpated!"
fi
