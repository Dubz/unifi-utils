#!/bin/sh

# unifi-utils
# vars.sh
# Utilities used to automate tasks with UniFi setups
# by Dubz <https://github.com/Dubz>
# from unifi-utils <https://github.com/Dubz/unifi-utils>
# Version 2.0-dev
# Last Updated December 05, 2020


# Service and other global variables
CONTROLLER_KEYSTORE_ALIAS=unifi
CONTROLLER_KEYSTORE_PASSWORD=aircontrolenterprise
CONTROLLER_SERVICE_UNIFI_SDN=unifi
CONTROLLER_SERVICE_UNIFI_PROTECT=unifi-protect
CONTROLLER_SERVICE_UNIFI_ACCESS=unifi-access
CONTROLLER_SERVICE_UNIFI_TALK=unifi-talk
# Assumed unifi-led right now
CONTROLLER_SERVICE_UNIFI_LED=unifi-led


# Deafult SSL locations for UI products
declare -A DEFAULT_SSL_LOCATION

# UC-CK
declare -A DEFAULT_SSL_LOCATION["UC-CK"]
declare -A DEFAULT_SSL_LOCATION["UC-CK"]["legacy"]
DEFAULT_SSL_LOCATION["UC-CK"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
DEFAULT_SSL_LOCATION["UC-CK"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
DEFAULT_SSL_LOCATION["UC-CK"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
DEFAULT_SSL_LOCATION["UC-CK"]["legacy"]["PRE_DEPLOY_EXEC"]="service ${CONTROLLER_SERVICE_UNIFI_SDN} stop"
DEFAULT_SSL_LOCATION["UC-CK"]["legacy"]["POST_DEPLOY_EXEC"]="service ${CONTROLLER_SERVICE_UNIFI_SDN} start; service nginx reload"


# UCK-G2 (ASSUMED, NOT VERIFIED)
declare -A DEFAULT_SSL_LOCATION["UCK-G2"]
declare -A DEFAULT_SSL_LOCATION["UCK-G2"]["legacy"]
declare -A DEFAULT_SSL_LOCATION["UCK-G2"]["UniOS"]
DEFAULT_SSL_LOCATION["UCK-G2"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
DEFAULT_SSL_LOCATION["UCK-G2"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
DEFAULT_SSL_LOCATION["UCK-G2"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
DEFAULT_SSL_LOCATION["UCK-G2"]["legacy"]["PRE_DEPLOY_EXEC"]="service ${CONTROLLER_SERVICE_UNIFI_SDN} stop"
DEFAULT_SSL_LOCATION["UCK-G2"]["legacy"]["POST_DEPLOY_EXEC"]="service ${CONTROLLER_SERVICE_UNIFI_SDN} start; service nginx reload"
DEFAULT_SSL_LOCATION["UCK-G2"]["UniOS"]["KEYSTORE"]=false
DEFAULT_SSL_LOCATION["UCK-G2"]["UniOS"]["KEY"]="/data/unifi-core/config/unifi-core.key"
DEFAULT_SSL_LOCATION["UCK-G2"]["UniOS"]["CRT"]="/data/unifi-core/config/unifi-core.crt"
DEFAULT_SSL_LOCATION["UCK-G2"]["UniOS"]["PRE_DEPLOY_EXEC"]=""
DEFAULT_SSL_LOCATION["UCK-G2"]["UniOS"]["POST_DEPLOY_EXEC"]=""

# UCK-G2-PLUS
declare -A DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]
declare -A DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["legacy"]
declare -A DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["UniOS"]
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["legacy"]["PRE_DEPLOY_EXEC"]="service ${CONTROLLER_SERVICE_UNIFI_SDN} stop"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["legacy"]["POST_DEPLOY_EXEC"]="service ${CONTROLLER_SERVICE_UNIFI_SDN} start; service nginx reload; if [ \"${CONTROLLER_RUNNING_PROTECT}\" ]; then service ${CONTROLLER_SERVICE_UNIFI_PROTECT} reload fi"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["UniOS"]["KEYSTORE"]=false
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["UniOS"]["KEY"]="/data/unifi-core/config/unifi-core.key"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["UniOS"]["CRT"]="/data/unifi-core/config/unifi-core.crt"
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["UniOS"]["PRE_DEPLOY_EXEC"]=""
DEFAULT_SSL_LOCATION["UCK-G2-PLUS"]["UniOS"]["POST_DEPLOY_EXEC"]=""


# UDM
declare -A DEFAULT_SSL_LOCATION["UDM"]
declare -A DEFAULT_SSL_LOCATION["UDM"]["UniOS"]
# These more than likely won't have a legacy OS in production ever, and since we don't know the official original target path, leaving commented out
#DEFAULT_SSL_LOCATION["UDM"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
#DEFAULT_SSL_LOCATION["UDM"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
#DEFAULT_SSL_LOCATION["UDM"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
#DEFAULT_SSL_LOCATION["UDM"]["legacy"]["PRE_DEPLOY_EXEC"]=false
#DEFAULT_SSL_LOCATION["UDM"]["legacy"]["POST_DEPLOY_EXEC"]=false
DEFAULT_SSL_LOCATION["UDM"]["UniOS"]["KEYSTORE"]=false
DEFAULT_SSL_LOCATION["UDM"]["UniOS"]["KEY"]="/data/unifi-core/config/unifi-core.key"
DEFAULT_SSL_LOCATION["UDM"]["UniOS"]["CRT"]="/data/unifi-core/config/unifi-core.crt"
DEFAULT_SSL_LOCATION["UDM"]["UniOS"]["PRE_DEPLOY_EXEC"]=""
DEFAULT_SSL_LOCATION["UDM"]["UniOS"]["POST_DEPLOY_EXEC"]=""

# UDM-Pro
declare -A DEFAULT_SSL_LOCATION["UDM-Pro"]
declare -A DEFAULT_SSL_LOCATION["UDM-Pro"]["UniOS"]
# These more than likely won't have a legacy OS in production ever, and since we don't know the official original target path, leaving commented out
#DEFAULT_SSL_LOCATION["UDM-Pro"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
#DEFAULT_SSL_LOCATION["UDM-Pro"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
#DEFAULT_SSL_LOCATION["UDM-Pro"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
#DEFAULT_SSL_LOCATION["UDM-Pro"]["legacy"]["PRE_DEPLOY_EXEC"]=false
#DEFAULT_SSL_LOCATION["UDM-Pro"]["legacy"]["POST_DEPLOY_EXEC"]=false
DEFAULT_SSL_LOCATION["UDM-Pro"]["UniOS"]["KEYSTORE"]=false
DEFAULT_SSL_LOCATION["UDM-Pro"]["UniOS"]["KEY"]="/data/unifi-core/config/unifi-core.key"
DEFAULT_SSL_LOCATION["UDM-Pro"]["UniOS"]["CRT"]="/data/unifi-core/config/unifi-core.crt"
DEFAULT_SSL_LOCATION["UDM-Pro"]["UniOS"]["PRE_DEPLOY_EXEC"]=""
DEFAULT_SSL_LOCATION["UDM-Pro"]["UniOS"]["POST_DEPLOY_EXEC"]=""


# UNVR
declare -A DEFAULT_SSL_LOCATION["UNVR"]
declare -A DEFAULT_SSL_LOCATION["UNVR"]["UniOS"]
# These more than likely won't have a legacy OS in production ever, and since we don't know the official original target path, leaving commented out
#DEFAULT_SSL_LOCATION["UNVR"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
#DEFAULT_SSL_LOCATION["UNVR"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
#DEFAULT_SSL_LOCATION["UNVR"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
#DEFAULT_SSL_LOCATION["UNVR"]["legacy"]["PRE_DEPLOY_EXEC"]=false
#DEFAULT_SSL_LOCATION["UNVR"]["legacy"]["POST_DEPLOY_EXEC"]=false
DEFAULT_SSL_LOCATION["UNVR"]["UniOS"]["KEYSTORE"]=false
DEFAULT_SSL_LOCATION["UNVR"]["UniOS"]["KEY"]="/data/unifi-core/config/unifi-core.key"
DEFAULT_SSL_LOCATION["UNVR"]["UniOS"]["CRT"]="/data/unifi-core/config/unifi-core.crt"
DEFAULT_SSL_LOCATION["UNVR"]["UniOS"]["PRE_DEPLOY_EXEC"]=""
DEFAULT_SSL_LOCATION["UNVR"]["UniOS"]["POST_DEPLOY_EXEC"]=""

# UNVR-Pro (ASSUMED, NOT VERIFIED)
declare -A DEFAULT_SSL_LOCATION["UNVR-Pro"]
declare -A DEFAULT_SSL_LOCATION["UNVR-Pro"]["UniOS"]
# These more than likely won't have a legacy OS in production ever, and since we don't know the official original target path, leaving commented out
#DEFAULT_SSL_LOCATION["UNVR-Pro"]["legacy"]["KEYSTORE"]="/etc/ssl/private/unifi.keystore.jks"
#DEFAULT_SSL_LOCATION["UNVR-Pro"]["legacy"]["KEY"]="/etc/ssl/private/cloudkey.key"
#DEFAULT_SSL_LOCATION["UNVR-Pro"]["legacy"]["CRT"]="/etc/ssl/private/cloudkey.crt"
#DEFAULT_SSL_LOCATION["UNVR-Pro"]["legacy"]["PRE_DEPLOY_EXEC"]=false
#DEFAULT_SSL_LOCATION["UNVR-Pro"]["legacy"]["POST_DEPLOY_EXEC"]=false
DEFAULT_SSL_LOCATION["UNVR-Pro"]["UniOS"]["KEYSTORE"]=false
DEFAULT_SSL_LOCATION["UNVR-Pro"]["UniOS"]["KEY"]="/data/unifi-core/config/unifi-core.key"
DEFAULT_SSL_LOCATION["UNVR-Pro"]["UniOS"]["CRT"]="/data/unifi-core/config/unifi-core.crt"
DEFAULT_SSL_LOCATION["UNVR-Pro"]["UniOS"]["PRE_DEPLOY_EXEC"]=""
DEFAULT_SSL_LOCATION["UNVR-Pro"]["UniOS"]["POST_DEPLOY_EXEC"]=""
