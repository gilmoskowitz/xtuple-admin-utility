#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

sudo apt-get -y install fail2ban
sudo apt-get -y install ntp ntpdate
sudo apt-get -y install libio-all-lwp-perl
sudo apt-get -y install libdbd-pg-perl
sudo apt-get -y install munin-node
sudo munin-node-configure --suggest

sudo mkdir -p /var/lib/munin/.ssh

(echo 'command="/bin/false",no-agent-forwarding,no-pty,no-user-rc,no-X11-forwarding,permitopen="localhost:4949" ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC4mp44eypjrsZWYMMrJcDPZKRlHUCb2anuh+uQOaro8pztGo9YwVHMOs8nauQ8yyop/iKk7dwfPgnzDxipw4U24Foxwu6iZLx4RPoPpe68fL/GBf6CbE0l6jHz+Q3XZq/lHi41563fBQXsELQKBFydNSTET+XrEHYEl8s1Yobm5zK5ILMbNwDDYeKTyCDy/OZj90B/NUOh4KewgL3WXZXTX03ji2j/1ZLKBK1pa6THx+dsypXj6aVu1fG6CkBNX3QrWLDNaZLvVqkN2Vjep20ZbQEeT+7ZR+AlyQ2iYeGd057MMqHi2416DuJ6ZXhFlD928M012dxDW6tdK9oXkEKz munin@xtuple'
 echo ' ') | sudo tee -a /var/lib/munin/.ssh/authorized_keys >/dev/null

sudo chown -R munin:munin /var/lib/munin
sudo chown -R munin:munin /var/lib/munin/.ssh/authorized_keys

#if nginx installed, then do this.

if type "nginx" > /dev/null; then
  wget https://github.com/perusio/nginx-munin/archive/master.zip
  unzip master.zip
  sudo cp nginx-munin-master/nginx_connection_request nginx_memory /etc/munin/plugins/ -fv
  sudo cp nginx-munin-master/nginx_memory /etc/munin/plugins/ -fv
fi

sudo service munin-node restart

