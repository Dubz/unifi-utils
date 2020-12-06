#!/bin/sh

# unifi-utils
# func.sh
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


# Check if the config file was loaded
if [ -z "${CONFIG_LOADED+x}" ]; then
    echo "CONFIG NOT LOADED!"
    echo "CONFIG MUST BE LOADED BEFORE FUNCTIONS!"
    exit 1
fi


# $1 - command to execute on controller
function send_eval() {
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        eval "${1}"
    else
        sshpass -p "${CONTROLLER_PASS}" ssh -o "VerifyHostKeyDNS=yes" ${CONTROLLER_USER}@${CONTROLLER_HOST} 'eval "'${1}'"'
    fi
}

# $1 - File to check
function check_file_exist() {
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        if [ -f "$1" ]; then
            return true
        else
            return false
        fi
    else
        if sshpass -p "${CONTROLLER_PASS}" ssh -o "VerifyHostKeyDNS=yes" ${CONTROLLER_USER}@${CONTROLLER_HOST} 'test -e "'$1'"'; then
            return true
        else
            return false
        fi
    fi
}


# $1 str  - Remote/target file
function backup_file() {
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        if [ -s "${1}.orig" ]; then
            echo -n "Backup of original exists! Creating non-destructive backup as ${1}.bak...";
            sudo cp -n "${1}" "${1}.bak";
        else 
            echo -n "No original backup found. Creating backup as ${1}.orig...";
            sudo cp -n "${1}" "${1}.orig";
        fi
    else
        sshpass -p "${CONTROLLER_PASS}" ssh -o "VerifyHostKeyDNS=yes" ${CONTROLLER_USER}@${CONTROLLER_HOST} 'if [ -s "'${1}'.orig" ]; then echo -n "Backup of original exists! Creating non-destructive backup as '${1}'.bak..."; sudo cp -n "'${1}'" "'${1}'.bak"; else echo -n "no original backup found. Creating backup as '${1}'.orig..."; sudo cp -n "'${1}'" "'${1}'.orig"; fi'
    fi
}


# $1 str  - Keystore location on target
# $2 str  - Keystore alias
# $3 str  - Keystore password
# $4 str  - p12 cert location
function keytool_import() {
    send_eval \
        'keytool -importkeystore \
            -srckeystore "'${4}'" \
            -srcstoretype PKCS12 \
            -srcstorepass "'${3}'" \
            -destkeystore "'${1}'" \
            -deststorepass "'${3}'" \
            -destkeypass "'${3}'" \
            -alias "'${2}'"'
}


# $1 str  - Keystore location on target
# $2 str  - Keystore alias
# $3 str  - Keystore password
function keytool_delete() {
    send_eval 'keytool -delete -alias "'${2}'" -keystore "'${1}'" -deststorepass "'${3}'"'
}


# $1 str  - Location of local file
# $2 str  - Location of target file
function copy_file() {
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        cp "${1}" "${2}"
    else
        sshpass -p "${CONTROLLER_PASS}" scp -q -o "VerifyHostKeyDNS=yes" "${1}" ${CONTROLLER_USER}@${CONTROLLER_HOST}:"${2}"
    fi
}


# $1 str  - File to remove
function remove_file() {
    send_eval 'rm "'${1}'"'
}
