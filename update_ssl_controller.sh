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

if [ "${CERTBOT_RUN_CONTROLLER}" != "true" ]; then
    echo "Controller is not to be updated based on ./config"
    return
    exit 0
fi

# Clone from external server to local server (if used)
if [ "${CERTBOT_USE_EXTERNAL}" == "true" ] && [ "${BRIDGE_SYNCED}" != "true" ]; then
    source get_ssl_bridge.sh
fi


# Are the required cert files there?
for f in cert.pem fullchain.pem privkey.pem
do
    if [ ! -s "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/${f}" ]; then
        echo "Missing file: ${f} - aborting!"
        return
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
        # Did it change there? If no, no sense in continuing...
        if [ "${CONTROLLER_IS_CK}" == "true" ]; then
            if [ "${CONTROLLER_LOCAL}" == "true" ]; then
                sha512_controller=$(openssl rsa -noout -modulus -in "/etc/ssl/private/cloudkey.key" | openssl sha512)
            else
                sha512_controller=$(sshpass -p "${CONTROLLER_PASS}" ssh -o LogLevel=error ${CONTROLLER_USER}@${CONTROLLER_HOST} "openssl rsa -noout -modulus -in \"/etc/ssl/private/cloudkey.key\" | openssl sha512")
            fi
        else
            echo "Keys did not change, stopping!"
            exit 0
        fi
        if [ "${sha512_privkey}" != "${sha512_controller}" ]; then
            echo "Key is not on controller, installer will continue!"
        else
            echo "Keys did not change, stopping!"
            exit 0
        fi
    else
        echo "New key detected, installer will continue!"
    fi
fi


# Convert cert to PKCS12 format
echo -n "Exporting SSL certificate and key data into temporary PKCS12 file..."
openssl pkcs12 -export \
    -inkey "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/privkey.pem" \
    -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/fullchain.pem" \
    -out "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/fullchain.p12" \
    -name ${CONTROLLER_KEYSTORE_ALIAS} \
    -passout pass:${CONTROLLER_KEYSTORE_PASSWORD}
echo "done!"


# Everything is prepped, time to interact with the CloudKey!


# Backups backups backups!

# Backup original keystore on CK
echo -n "Creating backup of keystore on controller..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    if [ -s "${CONTROLLER_KEYSTORE}.orig" ]; then
        echo -n "Backup of original keystore exists! Creating non-destructive backup as keystore.bak...";
        sudo cp -n "${CONTROLLER_KEYSTORE}" "${CONTROLLER_KEYSTORE}.bak";
    else
        echo -n "no original keystore backup found. Creating backup as keystore.orig...";
        sudo cp -n "${CONTROLLER_KEYSTORE}" "${CONTROLLER_KEYSTORE}.orig";
    fi
else
    # sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "if [ -s \"${CONTROLLER_KEYSTORE}.orig\" ]; then cp -n \"${CONTROLLER_KEYSTORE}\" \"${CONTROLLER_KEYSTORE}.orig\"; else cp -n \"${CONTROLLER_KEYSTORE}\" \"${CONTROLLER_KEYSTORE}.bak\"; fi"
    sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} 'if [ -s "'${CONTROLLER_KEYSTORE}'.orig" ]; then echo -n "Backup of original keystore exists! Creating non-destructive backup as keystore.bak..."; sudo cp -n "'${CONTROLLER_KEYSTORE}'" "'${CONTROLLER_KEYSTORE}'.bak"; else echo -n "no original keystore backup found. Creating backup as keystore.orig..."; sudo cp -n "'${CONTROLLER_KEYSTORE}'" "'${CONTROLLER_KEYSTORE}'.orig"; fi'
fi
echo "done!"

# Backup original keys on CK for nginx
if [ "${CONTROLLER_IS_CK}" == "true" ]; then
    echo -n "Creating backups of cloudkey.key and cloudkey.crt on controller..."
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        for f in {cloudkey.key,cloudkey.crt}; do
            sudo cp -n "/etc/ssl/private/${f}" "/etc/ssl/private/${f}.bak";
        done
    else
        sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} 'for f in {cloudkey.key,cloudkey.crt}; do sudo cp -n "/etc/ssl/private/${f}" "/etc/ssl/private/${f}.bak"; done'
    fi
    echo "done!"
fi


# Copy over...

# Copy to CK
echo -n "Copying files to controller..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    if [ "${CONTROLLER_IS_CK}" == "true" ]; then
        cp "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/fullchain.pem" "/etc/ssl/private/cloudkey.crt"
        cp "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/privkey.pem" "/etc/ssl/private/cloudkey.key"
    fi
    cp "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/fullchain.p12" $"${CONTROLLER_JAVA_DIR}/data/fullchain.p12"
else
    if [ "${CONTROLLER_IS_CK}" == "true" ]; then
        sshpass -p "${CONTROLLER_PASS}" scp -q "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/fullchain.pem" ${CONTROLLER_USER}@${CONTROLLER_HOST}:"/etc/ssl/private/cloudkey.crt"
        sshpass -p "${CONTROLLER_PASS}" scp -q "${CERTBOT_LOCAL_DIR_CONFIG}/live/${CONTROLLER_HOST}/privkey.pem" ${CONTROLLER_USER}@${CONTROLLER_HOST}:"/etc/ssl/private/cloudkey.key"
    fi
    sshpass -p "${CONTROLLER_PASS}" scp -q "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/fullchain.p12" ${CONTROLLER_USER}@${CONTROLLER_HOST}:"${CONTROLLER_JAVA_DIR}/data/fullchain.p12"
fi
echo "done!"


# Stop service...
echo -n "Stopping UniFi Controller..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    service ${CONTROLLER_SERVICE_UNIFI_NETWORK} stop
else
    sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service ${CONTROLLER_SERVICE_UNIFI_NETWORK} stop"
fi
echo "done!"


# Load keystore changes
echo -n "Removing previous certificate data from UniFi keystore..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    keytool -delete -alias ${CONTROLLER_KEYSTORE_ALIAS} -keystore ${CONTROLLER_KEYSTORE} -deststorepass ${CONTROLLER_KEYSTORE_PASSWORD}
else
    sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "keytool -delete -alias ${CONTROLLER_KEYSTORE_ALIAS} -keystore ${CONTROLLER_KEYSTORE} -deststorepass ${CONTROLLER_KEYSTORE_PASSWORD}"
fi
echo "done!"
echo -n "Importing SSL certificate into UniFi keystore..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    keytool -importkeystore \
        -srckeystore \"${CONTROLLER_JAVA_DIR}/data/fullchain.p12\" \
        -srcstoretype PKCS12 \
        -srcstorepass ${CONTROLLER_KEYSTORE_PASSWORD} \
        -destkeystore ${CONTROLLER_KEYSTORE} \
        -deststorepass ${CONTROLLER_KEYSTORE_PASSWORD} \
        -destkeypass ${CONTROLLER_KEYSTORE_PASSWORD} \
        -alias ${CONTROLLER_KEYSTORE_ALIAS}
else
    sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "keytool -importkeystore \
        -srckeystore \"${CONTROLLER_JAVA_DIR}/data/fullchain.p12\" \
        -srcstoretype PKCS12 \
        -srcstorepass ${CONTROLLER_KEYSTORE_PASSWORD} \
        -destkeystore ${CONTROLLER_KEYSTORE} \
        -deststorepass ${CONTROLLER_KEYSTORE_PASSWORD} \
        -destkeypass ${CONTROLLER_KEYSTORE_PASSWORD} \
        -alias ${CONTROLLER_KEYSTORE_ALIAS}"
fi
echo "done!"


# Reload... (jk doesn't work with SDN part...)
# echo -n "Reloading UniFi Controller to apply new Let's Encrypt SSL certificate..."
# sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service ${CONTROLLER_SERVICE_UNIFI_NETWORK} reload"
# echo "done!"
# Start service back up
echo -n "Restarting UniFi Controller to apply new Let's Encrypt SSL certificate..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    service ${CONTROLLER_SERVICE_UNIFI_NETWORK} start
else
    sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service ${CONTROLLER_SERVICE_UNIFI_NETWORK} start"
fi
echo "done!"

# Reload nginx on the CloudKey
echo -n "Reloading nginx..."
if [ "${CONTROLLER_IS_CK}" == "true" ]; then
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        service nginx reload
    else
        sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service nginx reload"
    fi
fi
echo "done!"

if [ "${CONTROLLER_IS_CK}" == "true" ] && [ "${CONTROLLER_HAS_PROTECT}" == "true" ]; then
    # Reload Protect On the CloudKey
    echo -n "Reloading UniFi Protect..."
    if [ "${CONTROLLER_LOCAL}" == "true" ]; then
        service ${CONTROLLER_SERVICE_UNIFI_PROTECT} reload
    else
        sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "service ${CONTROLLER_SERVICE_UNIFI_PROTECT} reload"
    fi
    echo "done!"
fi


echo -n "Cleaning up CloudKey..."
if [ "${CONTROLLER_LOCAL}" == "true" ]; then
    rm -f "${CONTROLLER_JAVA_DIR}/data/fullchain.p12"
else
    sshpass -p "${CONTROLLER_PASS}" ssh ${CONTROLLER_USER}@${CONTROLLER_HOST} "rm -f \"${CONTROLLER_JAVA_DIR}/data/fullchain.p12\""
fi
echo "done!"


# Save the new key hash to the cache for next run
echo -n "Caching cert hash..."
echo ${sha512_privkey} > "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512"
# Log for reference
echo ${sha512_privkey} >> "${CERTBOT_LOCAL_DIR_CACHE}/${CONTROLLER_HOST}/sha512.log"
echo "done!"


# Done!
echo "Process completed!"
return
exit 0
