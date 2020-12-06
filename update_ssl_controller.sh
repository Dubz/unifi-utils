#!/bin/sh

# unifi-utils
# controller_update_ssl.sh
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
if ! [ type check_file_exist &> /dev/null ]; then
    source func.sh
fi

# Does this run according to the config?
if [ "${CERTBOT_RUN_CONTROLLER}" != "true" ]; then
    echo "Controller is not to be updated based on ./config"
    return
    exit 0
fi

# Clone from external server to local server (if used)
if [ "${CERTBOT_USE_EXTERNAL}" == "true" ] && [ "${BRIDGE_SYNCED}" != "true" ]; then
    source get_ssl_bridge.sh
fi


# What's the target?
if [ "${CONTROLLER_TARGET_DEVICE}" == "SELFHOST" ]; then
    CONTROLLER_SSL_KEYSTORE=${CONTROLLER_SELFHOST_SSL_KEYSTORE}
    CONTROLLER_SSL_KEY=${CONTROLLER_SELFHOST_SSL_KEY}
    CONTROLLER_SSL_CRT=${CONTROLLER_SELFHOST_SSL_CRT}
    CONTROLLER_SSL_PRE_DEPLOY_EXEC=${CONTROLLER_SELFHOST_SSL_PRE_DEPLOY_EXEC}
    CONTROLLER_SSL_POST_DEPLOY_EXEC=${CONTROLLER_SELFHOST_SSL_POST_DEPLOY_EXEC}
elif [ "${CONTROLLER_TARGET_DEVICE}" == "DOCKER" ]; then
    CONTROLLER_SSL_KEYSTORE=${CONTROLLER_DOCKER_SSL_KEYSTORE}
    CONTROLLER_SSL_KEY=${CONTROLLER_DOCKER_SSL_KEY}
    CONTROLLER_SSL_CRT=${CONTROLLER_DOCKER_SSL_CRT}
    CONTROLLER_SSL_PRE_DEPLOY_EXEC=${CONTROLLER_DOCKER_SSL_PRE_DEPLOY_EXEC}
    CONTROLLER_SSL_POST_DEPLOY_EXEC=${CONTROLLER_DOCKER_SSL_POST_DEPLOY_EXEC}
else
    # Pull the targets from vars.sh
    if [ "${CONTROLLER_TARGET_IS_UNIOS}" ]; then
        if [ "${DEFAULT_SSL_LOCATION[\"${CONTROLLER_TARGET_DEVICE}-UniOS-KEY\"]}" ]; then
            CONTROLLER_SSL_KEYSTORE=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-UniOS-KEYSTORE"]}
            CONTROLLER_SSL_KEY=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-UniOS-KEY"]}
            CONTROLLER_SSL_CRT=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-UniOS-CRT"]}
            CONTROLLER_SSL_PRE_DEPLOY_EXEC=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-UniOS-PRE_DEPLOY_EXEC"]}
            CONTROLLER_SSL_POST_DEPLOY_EXEC=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-UniOS-POST_DEPLOY_EXEC"]}
        else
            echo "Target not supported!"
            return
            exit 1
        fi
    else
        if [ "${DEFAULT_SSL_LOCATION[\"${CONTROLLER_TARGET_DEVICE}-legacy-KEY\"]}" ]; then
            CONTROLLER_SSL_KEYSTORE=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-legacy-KEYSTORE"]}
            CONTROLLER_SSL_KEY=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-legacy-KEY"]}
            CONTROLLER_SSL_CRT=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-legacy-CRT"]}
            CONTROLLER_SSL_PRE_DEPLOY_EXEC=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-legacy-PRE_DEPLOY_EXEC"]}
            CONTROLLER_SSL_POST_DEPLOY_EXEC=${DEFAULT_SSL_LOCATION["${CONTROLLER_TARGET_DEVICE}-legacy-POST_DEPLOY_EXEC"]}
        else
            echo "Target not supported!"
            return
            exit 1
        fi
    fi
fi

# Basic check for an actual destination
# Default blank/empty to false for ease of checking
if [ "${CONTROLLER_SSL_KEY}" == "" ]; then CONTROLLER_SSL_KEY=false; fi
if [ "${CONTROLLER_SSL_CRT}" == "" ]; then CONTROLLER_SSL_CRT=false; fi
if [ "${CONTROLLER_SSL_KEYSTORE}" == "" ]; then CONTROLLER_SSL_KEYSTORE=false; fi

if [ "${CONTROLLER_SSL_KEY}" == "false" ] || [ "${CONTROLLER_SSL_CRT}" == "false" ]; then
    if [ "${CONTROLLER_SSL_KEYSTORE}" == "false" ]; then
        echo "Install target required!"
        return
        exit 1
    fi
fi


# Are the required cert files there?
for f in "${SSLCERT_CERT}" "${SSLCERT_FULLCHAIN}" "${SSLCERT_KEY}"
do
    if [ ! -s "${f}" ]; then
        echo "Missing file: ${f} - aborting!"
        return
        exit 1
    fi
done


# Time to check/verify cert information now
# At this point, we are to assume:
#  1) The config has been set up
#  2) The cert files needed are on this machine
#  3) Everything needed to perform this operation is loaded
# We will first verify we have files to work with
# Once we have them, we will verify integrity with one another
# After that, see if it's already installed on the destination device
# If it is not, proceed with the deployment


# Create cache directory/file if they don't already exist
if [ ! -f "${SSLCERT_LOCAL_DIR_CACHE}/sha512" ]; then
    if [ ! -d "${SSLCERT_LOCAL_DIR_CACHE}/" ]; then
        mkdir --parents "${SSLCERT_LOCAL_DIR_CACHE}/"
    fi
    touch "${SSLCERT_LOCAL_DIR_CACHE}/sha512"
fi

# Check cert integrity, and for any changes/differences, before doing anything on the controller
# We'll check all 3 just because, even though we're only using 2 of them
echo -n "Checking certificate integrity..."
sha512_cert=$(openssl x509 -noout -modulus -in "${SSLCERT_CERT}" | openssl sha512)
sha512_fullchain=$(openssl x509 -noout -modulus -in "${SSLCERT_FULLCHAIN}" | openssl sha512)
sha512_privkey=$(openssl rsa -noout -modulus -in "${SSLCERT_KEY}" | openssl sha512)
sha512_last=$(<"${SSLCERT_LOCAL_DIR_CACHE}/sha512")
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
    # Did the keys change? If not, no sense in continuing...
    if [ "${sha512_privkey}" == "${sha512_last}" ]; then
        echo "NOTE: Local cache for last deployment matches current key."
        if [ "${CONTROLLER_SSL_KEY}" != "false" ]; then
            # Did it change there? If no, no sense in continuing...
            if [ "${CONTROLLER_LOCAL}" == "true" ]; then
                sha512_controller=$(openssl rsa -noout -modulus -in "${CONTROLLER_SSL_KEY}" | openssl sha512)
            else
                sha512_controller=$(sshpass -p "${CONTROLLER_PASS}" ssh -o "VerifyHostKeyDNS=yes" -o "LogLevel=error" ${CONTROLLER_USER}@${CONTROLLER_HOST} "openssl rsa -noout -modulus -in \"${CONTROLLER_SSL_KEY}\" | openssl sha512")
            fi
            if [ "${sha512_privkey}" != "${sha512_controller}" ]; then
                echo "Key is not on controller, installer will continue!"
            else
                echo "Keys did not change, stopping!"
                return
                exit 0
            fi
        else
            echo "SSL key file does not exist on target."
            echo "Aborting install, since the local cache matches current key."
            return
            exit 0
        fi
    else
        echo "New key detected, installer will continue!"
    fi
fi


# Convert cert to PKCS12 format
if [ ! -s "${SSLCERT_FULLCHAIN_P12}" ]; then
    echo -n "Exporting SSL certificate and key data into temporary PKCS12 file..."
    openssl pkcs12 -export \
        -inkey "${SSLCERT_KEY}" \
        -in "${SSLCERT_FULLCHAIN}" \
        -out "${SSLCERT_FULLCHAIN_P12}" \
        -name ${CONTROLLER_KEYSTORE_ALIAS} \
        -passout pass:${CONTROLLER_KEYSTORE_PASSWORD}
    echo "done!"
else
    echo "SSL certificate already provided in PKCS12 format, continuing."
fi


# Everything is prepped, time to interact with the Controller!

# Pre-deployment command
if [ "${CONTROLLER_SSL_PRE_DEPLOY_EXEC}" ]; then
    echo "Running pre-deployment command..."
    send_exec ${CONTROLLER_SSL_PRE_DEPLOY_EXEC}
    echo "Pre-deployment command execution completed!"
else
    echo "No pre-deployment command found, starting!"
fi




# Backups backups backups!

# Backup key(s) on Controller
if [ "${CONTROLLER_SSL_KEY}" != "false" ]; then
    for key in "${CONTROLLER_SSL_KEY}"
    do
        backup_file ${key}
    done
fi
# Backup cert(s) on Controller
if [ "${CONTROLLER_SSL_CRT}" != "false" ]; then
    for crt in "${CONTROLLER_SSL_CRT}"
    do
        backup_file ${crt}
    done
fi

# Backup keystore(s) on Controller
if [ "${CONTROLLER_SSL_KEYSTORE[@]}" != "false" ]; then
    for ks in "${CONTROLLER_SSL_KEYSTORE[@]}"
    do
        echo -n "Creating backup of ${ks} on controller..."
        backup_file ${ks}
        echo "done!"
    done
fi


# Time to deploy crts/keys
echo -n "Copying files to controller..."
if [ "${CONTROLLER_SSL_KEY[@]}" != "false" ]; then
    for ssl_key in "${CONTROLLER_SSL_KEY[@]}"
    do
        copy_file "${SSLCERT_KEY}" "${ssl_key}"
    done
fi

if [ "${CONTROLLER_SSL_CRT[@]}" != "false" ]; then
    for ssl_crt in "${CONTROLLER_SSL_CRT[@]}"
    do
        copy_file "${SSLCERT_FULLCHAIN}" "${ssl_crt}"
    done
fi
if [ "${CONTROLLER_SSL_KEYSTORE[@]}" != "false" ]; then
    # This is deployed to a temporary/remote cache, then used to install to the keystore(s)
    copy_file "${SSLCERT_FULLCHAIN_P12}" "${SSLCERT_REMOTE_DIR_CACHE}/fullchain.p12"
fi
echo "done!"


# Deploy keystore
echo -n "Removing previous certificate data from ${CONTROLLER_KEYSTORE_ALIAS} keystore..."
if [ "${CONTROLLER_SSL_KEYSTORE[@]}" != "false" ]; then
    for ks in "${CONTROLLER_SSL_KEYSTORE[@]}"
    do
        keytool_delete "${ks}" "${CONTROLLER_KEYSTORE_ALIAS}" "${CONTROLLER_KEYSTORE_PASSWORD}"
    done
fi
echo "done!"
echo -n "Importing SSL certificate into ${CONTROLLER_KEYSTORE_ALIAS} keystore..."
if [ "${CONTROLLER_SSL_KEYSTORE[@]}" != "false" ]; then
    for ks in "${CONTROLLER_SSL_KEYSTORE[@]}"
    do
        keytool_import "${ks}" "${CONTROLLER_KEYSTORE_ALIAS}" "${CONTROLLER_KEYSTORE_PASSWORD}" "${SSLCERT_FULLCHAIN_P12}"
    done
fi
echo "done!"




# Post-deployment command
if [ "${CONTROLLER_SSL_POST_DEPLOY_EXEC}" ]; then
    echo "Running post-deployment command..."
    send_exec ${CONTROLLER_SSL_POST_DEPLOY_EXEC}
    echo "Post-deployment command execution completed!"
else
    echo "No post-deployment command found, finishing!"
fi


echo -n "Cleaning up CloudKey..."
send_exec "rm -f \"${SSLCERT_REMOTE_DIR_CACHE}/fullchain.p12\""
echo "done!"


# Save the new key hash to the cache for next run
echo -n "Caching cert hash..."
echo ${sha512_privkey} > "${SSLCERT_LOCAL_DIR_CACHE}/sha512"
# Log for reference
echo ${sha512_privkey} >> "${SSLCERT_LOCAL_DIR_CACHE}/sha512.log"
echo "done!"


# Done!
echo "Process completed!"
return
exit 0
