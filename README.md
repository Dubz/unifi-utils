# unifi-utils
A collection of utilities to help automate tasks for Ubiquiti's UniFi products.

## get_ssl_bridge.sh
* This downloads SSL certs from the bridge server to the local server, if bridge mode is enabled
* Recommended cron run: 3 minutes after certbot runs (usually every 12 hours)

## update_ssl.sh
* This will run all update_ssl\*.sh scripts
* Recommended cron run: 5 minutes after certbot runs (usually every 12 hours)
  * This will only take action if the certs installed are not matching

## update_ssl_controller.sh
This will upload and install the SSL cert to your UniFi controller

## update_ssl_radius.sh
This will upload and install the SSL cert to your RADIUS server (ex. USG)

## WARNING
This setup will contain vital information, and have full control of your UniFI infrastructure.
Although this utility is doing its job, and nothing else, it is your responsibility to secure all authentication information!
This includes SSH keys and the config file (which contains the password to your controller, if used).

We recommend setting the config file's permissions to 0400 (read only for the user running this).

### Requirements
* certbot running for your domain (this does not run certbot, it copes the files needed)
* openssh-client (verifying certificate integrity)
* scp (copies certificate files to CloudKey)
* sshpass (used for password authentication into CloudKey, since FW upgrades may wipe SSH keys)

### INSTALLATION
1. As always, create a backup of your Controller. I am not responsible if you mess it up.
1. Copy the file "./config-default" to "./config"
1. Edit the "./config" file to suit your setup
1. Change the file's permissions to 0400
1. Add a cron entry to run update_ssl.sh as often as you'd like (it only makes changes if needed, recommended 5 minutes after certbot runs)

    Ex: `5 0,12 * * * cd path-to/unifi-utils && bash ./update_ssl.sh && cd ~`

### INSTALLATION (LetsEncrypt - CloudKey)
1. Edit the "./config" file to suit your setup
1. If using an external server (bridge mode):
  1. Generate an SSH key for your external server
  1. Add the public key to the external server
  1. Add entries to ~/.ssh/config for your external server
1. Change the file's permissions to 0400
1. Run update_ssl_controller.sh to verify operation

### INSTALLATION (LetsEncrypt - RADIUS - Linux/USG)
1. Edit the "./config" file to suit your setup
  1. Remove RADIUS_PASS from ./config
1. Generate an SSH key for your devices (if using USG, the type must be RSA. Complain to Ubiquiti if you have issues with this. It's their limitation, not mine)
  1. If using USG, add the public key to your SDN (Settings > Site > Device Authentication)
  1. Add entry to ~/.ssh/config
1. Run update_ssl_radius.sh to verify operation

### INSTALLATION (RADIUS - Other)
* There is currently no support for other RADIUS servers at this time. Please submit a PR if you would like to optionally add support for one

#### Using bridge mode
You can optionally use this in a "bridge" mode. This will allow you to pull (clone) files from a remote server running certbot, then continue the normal operation of pushing the necessary files to the CloudKey.
1. Add an entry to ~/.ssh/config for the remote server running certbot, and edit the config at the top for the external server.
1. Add a cron entry to run get_ssl_bridge.sh after certbot runs, and prior to update_ssl.sh is set to run. You can combine the cron jobs to run back to back with one entry by concatenating the cron jobs

    Ex: `5 0,12 * * * cd path-to/unifi-utils && bash ./get_ssl_bridge.sh && bash ./update_ssl.sh && cd ~`
###### Requirements
* rsync (downloads from remote certbot server)

#### Additional Notes
* External server steps are only required if using bridge mode
* This was made to be as simple as possible, yet still robust.
* Passwords are used for UniFi Controller only. Everything else will use SSH Keys referenced in ~/.ssh/config
* Tested on UCK-G2-PLUS running latest public firmware *(UCKP.apq8053.v1.0.9.92d728e.190709.1609)* and controller *(5.10.25-11682-1)*
* Tested on USG-PRO-4 running latest public furmware *(4.4.41.5193714)*
* Should also work on UC-CK, UCK-G2, and USG
* Compatibility with UDM and UDM-Pro is unknown at this time
* NOT tested on third party systems running SDN (ex. debian, docker, Windows Server, etc.)
  * These probably won't really benefit from this, since there aren't firmware updates that wipe other software, like certbot. May change in the future
* Any of these scripts can be run on demand at any time, or by cron job (recommended).

#### Known issues
* RADIUS cert installs, but still marked untrusted. If you have a solution to this, please open an issue/PR, or DM me.
* Protect did not seem to load it back up. Might've been situational, or may need a full restart to load it.

**The scripts provided are not affiliated with Ubiquiti, or any of its staff. Provided "as-is" without liability.**
