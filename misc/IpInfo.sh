#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

setupxtipinfo() {
  if [ -f /etc/issue.orig ]; then
    echo "/etc/issue.orig already exists!"
  else
    echo "creating issue.orig"
    cp /etc/issue /etc/issue.orig
  fi

  if [ -f /etc/network/if-up.d/xtipinfo ]; then
    echo "/etc/network/if-up.d/xtipinfo already exists!"
  else
    cat << EOF >> /etc/network/if-up.d/xtipinfo
#!/bin/sh
if [ "\$METHOD" = loopback ]; then
  exit 0
fi

# Only run from ifup.
if [ "\$MODE" != start ]; then
  exit 0
fi

cp /etc/issue.orig /etc/issue
/usr/local/bin/xt-ip-info.sh >> /etc/issue
EOF

    chmod 755 /etc/network/if-up.d/xtipinfo
  fi

  if [ -f /usr/local/bin/xt-ip-info.sh ]; then
    echo "/usr/local/bin/xt-ip-info.sh already exists!"
  else
    cat << EOF >> /usr/local/bin/xt-ip-info.sh
#!/bin/bash
LANIP=\$\(/sbin/ifconfig | grep "inet addr" | grep -v "127.0.0.1" | awk '{ print \$2 }' | awk -F: '{ print \$2 }'\)
WANIP=\$(\curl --connect-timeout 60 --silent -0 http://icanhazip.com\)

if [ -z "\$LANIP" ]; then
  LANSTAT="Cannot find LAN IP at this time"
  COL=31
else
  LANSTAT="OK - IP is \${LANIP}"
  COL=32
fi

if [ -z "\$WANIP" ]; then
  WANSTAT="Cannot find WAN IP at this time"
  COL=31
else
  WANSTAT="OK - IP is \${WANIP}"
  COL=32
fi

echo "\$SVRTXT";

echo -e "\\n";
echo -e "\\E[34;40m        #######"; tput sgr0
echo -e "\\E[34;40m #    #    #    #    # #####  #      ###### "; tput sgr0
echo -e "\\E[34;40m  #  #     #    #    # #    # #      #      "; tput sgr0
echo -e "\\E[34;40m   ##      #    #    # #    # #      #####  "; tput sgr0
echo -e "\\E[34;40m   ##      #    #    # #####  #      #      "; tput sgr0
echo -e "\\E[34;40m  #  #     #    #    # #      #      #      "; tput sgr0
echo -e "\\E[34;40m #    #    #     ####  #      ###### ###### "; tput sgr0
echo -e "\\E[34;00m                                            "; tput sgr0
echo -e "\\E[34;00m   Lan Status: \\E[\${COL};40m\${LANSTAT}   "; tput sgr0
echo -e "\\E[34;00m   Wan Status: \\E[\${COL};40m\${WANSTAT}   "; tput sgr0
echo -e "\\n";
EOF

  chmod 755 /usr/local/bin/xt-ip-info.sh
  fi
}

setupxtipinfo
