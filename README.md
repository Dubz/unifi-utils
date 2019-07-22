# uck-letsencrypt-certbot
This will allow a linux server (ex. Raspberry Pi) to easily push LetsEncrypt SSL certs to a Unifi CloudKey.
This is simply a file checking/transfer tool.

# Requirements
* certbot running for your domain (this does not run certbot, it copes the files needed)
* openssh-client (verifying certificate integrity)
* scp (copies certificate files to CloudKey)

# INSTALLATION
1. As always, create a backup of your CloudKey. I am not responsible if you mess it up.
1. Generate an SSH key pair for your server/CloudKey
1. Place the public key on your CloudKey
1. Add an entry to your server's ~/.ssh/config file
1. Place the unifi_ssl_cron.sh file on your server (wherever you'd like)
1. Edit the variables at the top of the script to suit your needs
1. Run the script to verify operation
1. Add a cron entry to run unifi_ssl_cron.sh after certbot (ex. 5 minutes after)

## Using bridge mode
You can optionally use this in a "bridge" mode. This will allow you to pull (clone) files from a remote server running certbot, then continue the normal operation of pushing the necessary files to the CloudKey. Simply add a second entry to ~/.ssh/config for the remote server running certbot, and edit the options at the top for the external server.
#### Requirements
* rsync (downloads from remote certbot server)

## Additional Notes
* This was made to be as simple as possible, yet still robust.
* Tested on UCK-G2-PLUS running latest public firmware *(UCKP.apq8053.v1.0.9.92d728e.190709.1609)* and controller *(5.10.25-11682-1)*
* Support for SSH keys to connect to the CloudKey will depend on if the keys get wiped during a firmware update. If this is the case, password authentication will be added instead, and thus remove all dependencies on the CloudKey.
* This can be run on demand at any time, or by cron job (recommended). You will need to run this after firmware updates to reinstall the SSL certificate, or let the cron get to it when the time comes.

**The script provided is not affiliated with Ubiquiti, or any of its staff. Provided "as-is" without liability.**
