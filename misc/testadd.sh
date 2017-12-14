#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

HIGHHTTP=$(grep 'server 127.0.0.1:100'  /etc/nginx/sites-available/* | cut -d':' -f 3 | cut -d ';' -f 1 | sort -r |head -1)
NEWHTTP=$(expr $HIGHHTTP + 1)

HIGHHTTPS=$(grep 'server 127.0.0.1:104'  /etc/nginx/sites-available/* | cut -d':' -f 3 | cut -d ';' -f 1 | sort -r |head -1)
NEWHTTPS=$(expr $HIGHHTTPS + 1)

echo "New HTTP = $NEWHTTP , New HTTPS = $NEWHTTPS"
exit 0;
