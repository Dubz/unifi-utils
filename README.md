# uck-letsencrypt-certbot
This will allow a linux server (ex. Raspberry Pi) to easily push LetsEncrypt SSL certs to a Unifi CloudKey.

# Requirements
* openssh-client (verifying certificate integrity)
* scp (copies certificate files to CloudKey)

# INSTALLATION
1. Generate an SSH key pair for your server/CloudKey
1. Place the public key on your CloudKey
1. Add an entry to your server's ~/.ssh/config file
1. Place the unifi_ssl_cron.sh file on your server
1. Edit the variables at the top to suit your needs
1. Run the script to verify operation
1. Add a cron entry to run unifi_ssl_cron.sh after certbot (ex. 5 minutes after)

## Using bridge mode
You can optionally use this in a "bridge" mode. This will allow you to pull (clone) files from a remote server running certbot, then continue the normal operation of pushing the necessary files to the CloudKey. Simply add a second entry to ~/.ssh/config for the remote server running certbot, and edit the options at the top for the external server.
#### Requirements
* rsync (downloads from remote certbot server)

## Additional Notes
* Support for SSH keys to connect to the CloudKey will depend on if the keys get wiped during a firmware update. If this is the case, password authentication will be used instead, and remove all dependencies on the CloudKey.
