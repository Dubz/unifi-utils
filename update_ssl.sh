#!/bin/sh

# unifi-utils
# cron.sh
# Main script for Unifi Utils
# by Dubz <https://github.com/Dubz>
# from unifi-utils <https://github.com/Dubz/unifi-utils>
# Version 0.3
# Last Updated July 27, 2019

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

# Installer for controller
if [ "${CERTBOT_RUN_CONTROLLER}" == "true" ]; then
	echo "Running update_ssl_controller.sh..."
	source update_ssl_controller.sh
	echo "Controller SSL udpated!"
fi
# Installer for RADIUS server
if [ "${CERTBOT_RUN_RADIUS}" == "true" ]; then
	echo "Running update_ssl_radius.sh..."
	source update_ssl_radius.sh
	echo "RADIUS server SSL udpated!"
fi