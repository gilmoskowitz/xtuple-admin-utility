#! /bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

wget https://dl.eff.org/certbot-auto
chmod a+x certbot-auto
sudo chown root:root certbot-auto
sudo mv certbot-auto /usr/sbin

ERP_HOSTNAME=
ERP_DOMAIN=
ERP_FQDN=${ERP_HOSTNAME}.${ERP_DOMAIN}
ERP_WEBROOT=/usr/share/nginx/${ERP_FQDN}
ERP_DEFAULT=${ERP_DOMAIN}-defaults.conf
NGINX_AVAIL=/etc/nginx/sites-available
NGINX_ENABLE=/etc/nginx/sites-enabled

sudo mkdir -p /usr/share/nginx/${ERP_FQDN}

# generate dhparam.pem
mkdir /etc/nginx/ssl
openssl openssl dhparam -out /etc/nginx/ssl/dhparam.pem 4096

sudo certbot-auto certonly --webroot -w ${ERP_WEBROOT} -d ${ERP_FQDN}

# 30 1 * * * root perl -le 'sleep rand 9000' && /usr/sbin/certbot-auto renew --quiet --no-self-upgrade --post-hook "service nginx restart"

