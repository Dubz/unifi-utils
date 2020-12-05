#!/bin/sh

# unifi-utils
# update_ssl_radius.sh
# Utilities used to automate tasks with UniFi setups
# by Dubz <https://github.com/Dubz>
# from unifi-utils <https://github.com/Dubz/unifi-utils>
# Version 2.0-dev
# Last Updated December 05, 2020

# REQUIREMENTS
# 1) Assumes you already have a valid SSL certificate
# 2) ./config-default file copied to ./config and edited as necessary
# 3) Identities to be set up in ~/.ssh/config as needed

# KEY BACKUP
# Even though this script attempts to be clever and careful in how it backs up your existing key/cert,
# it's never a bad idea to manually back up your key/cert (located at /etc/ssl/private/ssl-cert-snakeoil.key
# and /etc/ssl/certs/ssl-cert-snakeoil.pem on the USG) to a separate directory before running this script.
# If anything goes wrong, you can restore from your backup, restart the RADIUS service,
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

# Load the necessary functions
if ! [ typeset -f check_file_exist > /dev/null ]; then
    source func.sh
fi

if [ "${CERTBOT_RUN_RADIUS}" != "true" ]; then
    echo "RADIUS is not to be updated based on ./config"
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
    if [ ! -s "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/${f}" ]; then
        echo "Missing file: ${f} - aborting!"
        return
        exit 1
    fi
done

# Create cache directory/file if not existing
if [ ! -s "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/sha512" ]; then
    if [ ! -d "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/" ]; then
        mkdir --parents "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/"
    fi
    touch "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/sha512"
fi

# Check integrity and for any changes/differences, before doing anything on the RADIUS server
# We'll check all 3 just because, even though we're only using 2 of them
echo -n "Checking certificate integrity..."
sha512_cert=$(openssl x509 -noout -modulus -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/cert.pem" | openssl sha512)
sha512_fullchain=$(openssl x509 -noout -modulus -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/fullchain.pem" | openssl sha512)
sha512_privkey=$(openssl rsa -noout -modulus -in "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/privkey.pem" | openssl sha512)
sha512_last=$(<"${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/sha512")
if [ "${sha512_privkey}" != "${sha512_cert}" ]; then
    echo "Private key and cert do not match!"
    return
    exit 1
elif [ "${sha512_privkey}" != "${sha512_fullchain}" ]; then
    echo "Private key and full chain do not match!"
    return
    exit 1
else
    echo "integrity passed!"
    # Did the key change? If not, no sense in continuing...
    if [ "${sha512_privkey}" == "${sha512_last}" ]; then
        # Did it change there? If no, no sense in continuing...
        sha512_controller=$(ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${RADIUS_USER}@${RADIUS_HOST} "sudo openssl rsa -noout -modulus -in \"${RADIUS_KEY}\" | openssl sha512")
        if [ "${sha512_privkey}" != "${sha512_controller}" ]; then
            echo "Key is not on controller, installer will continue!"
        else
            echo "Key did not change, stopping!"
            return
            exit 0
        fi
    else
        echo "New key detected, installer will continue!"
    fi
fi


# Everything is prepped, time to interact with the RADIUS server!


# Backups backups backups!

# Backup original key/cert on RADIUS
# echo -n "Creating backups of key and cert on server..."
# ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${RADIUS_USER}@${RADIUS_HOST} "if sudo test -s \"${RADIUS_CERT}.orig\"; then echo -n \"Backup of original cert exists! Creating non-destructive backup as ${RADIUS_CERT}.bak...\"; sudo cp \"${RADIUS_CERT}\" \"${RADIUS_CERT}.bak\"; else echo -n \"no original cert backup found. Creating backup as ${RADIUS_CERT}.orig...\"; sudo cp \"${RADIUS_CERT}\" \"${RADIUS_CERT}.orig\"; fi; if sudo test -s \"${RADIUS_KEY}.orig\"; then echo -n \"Backup of original key exists! Creating non-destructive backup as ${RADIUS_KEY}.bak...\"; sudo cp \"${RADIUS_KEY}\" \"${RADIUS_KEY}.bak\"; else echo -n \"no original key backup found. Creating backup as ${RADIUS_KEY}.orig...\"; sudo cp \"${RADIUS_KEY}\" \"${RADIUS_KEY}.orig\"; fi"
echo -n "Creating backup of pem key on server..."
ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${RADIUS_USER}@${RADIUS_HOST} "if sudo test -s \"${RADIUS_PEM}.orig\"; then echo -n \"Backup of original pem exists! Creating non-destructive backup as ${RADIUS_PEM}.bak...\"; sudo cp \"${RADIUS_PEM}\" \"${RADIUS_PEM}.bak\"; else echo -n \"no original pem backup found. Creating backup as ${RADIUS_PEM}.orig...\"; sudo cp \"${RADIUS_PEM}\" \"${RADIUS_PEM}.orig\"; fi;"
echo "done!"


# Copy over...

# Copy to RADIUS Server
echo -n "Merging cert files to server.pem for lighttpd..."
# lighttpd
cat "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/privkey.pem" "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/fullchain.pem" > "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/server.pem"
echo -n "Copying files to RADIUS server..."
# radius
scp -q "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/fullchain.pem" ${RADIUS_USER}@${RADIUS_HOST}:"~/fullchain.pem"
scp -q "${CERTBOT_LOCAL_DIR_CONFIG}/live/${RADIUS_HOST}/privkey.pem" ${RADIUS_USER}@${RADIUS_HOST}:"~/privkey.pem"
# lighttpd
scp -q "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/server.pem" ${RADIUS_USER}@${RADIUS_HOST}:"~/server.pem"
echo -n "moving to proper location..."
# radius
ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${RADIUS_USER}@${RADIUS_HOST} "sudo mv -f ~/fullchain.pem ${RADIUS_CERT}; sudo mv -f ~/privkey.pem ${RADIUS_KEY}; sudo chmod 644 ${RADIUS_CERT}; sudo chown root:ssl-cert ${RADIUS_CERT}; sudo chmod 640 ${RADIUS_KEY}; sudo chown root:ssl-cert ${RADIUS_KEY}"
# lighttpd
ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${RADIUS_USER}@${RADIUS_HOST} "sudo mv -f ~/server.pem ${RADIUS_PEM}; sudo chmod 400 ${RADIUS_PEM}; sudo chown root:root ${RADIUS_PEM};"
echo "done!"


# Reload service on the 
echo -n "Restarting ${RADIUS_SERVICE} and lighttpd..."
ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${RADIUS_USER}@${RADIUS_HOST} 'sudo service '${RADIUS_SERVICE}' restart; sudo kill -SIGTERM $(cat /var/run/lighttpd.pid); sudo /usr/sbin/lighttpd -f /etc/lighttpd/lighttpd.conf'
echo "done!"



# Save the new key hash to the cache for next run
echo -n "Caching cert hash..."
echo ${sha512_privkey} > "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/sha512"
# Log for reference
echo ${sha512_privkey} >> "${CERTBOT_LOCAL_DIR_CACHE}/${RADIUS_HOST}/sha512.log"
echo "done!"


# Done!
echo "Process completed!"
return
exit 0
