#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

# Installs Nagios NRPE for Monitor.xtuple.com

#Vars Needed for genconf()
CUST=ppctest
#PGPORT=
WORKDATE=$(/bin/date "+%m%d%y_%s")

if [[ -z $(which ec2metadata) ]]; then
DOMAIN=mydomain
MACHID=$(hostname -f)
DOMAIN=NA
MACHID=NA
FQDN=NA
LANIP=NA
WANIP=NA

else
DOMAIN=xtuplecloud.com
MACHID=$(ec2metadata --instance-id)
PUBNAME=$(ec2metadata --public-hostname)
FQDN=${CUST}.${DOMAIN}
LANIP=$(ec2metadata --local-ipv4)
WANIP=$(ec2metadata --public-ipv4)
fi



installpkg()
{
pkg=nagios-nrpe-server
HASNAG=$(dpkg --list | grep ${pkg} | wc -l)

if [ $HASNAG -eq 1 ];
then
echo "${pkg} is already installed." 
else
 if apt-get -qq install ${pkg}; then
    echo "Successfully installed $pkg"
 else
    echo "Error installing $pkg"
    exit 0
 fi
fi
}

installcfg()
{
NAGETC=/etc/nagios
CONFIGOUT=nrpe_local.cfg
WASHERE=$(grep command ${NAGETC}/${CONFIGOUT} | wc -l)

if [ ${WASHERE} == 0 ];
then
MSG="Sending config to ${NAGETC}/${CONFIGOUT}"

else
CONFIGOUT=nrpe_local.${WORKDATE}
MSG="We have a previously modified config. Sending to ${NAGETC}/${CONFIGOUT} for review."
fi

echo $MSG
cat << EOF >> ${NAGETC}/${CONFIGOUT}
### ADDED BY xTuple-Utility
allowed_hosts=23.21.178.187,127.0.0.1,monitor.xtuple.com

command[check_users]=/usr/lib/nagios/plugins/check_users -w 5 -c 10
command[check_load]=/usr/lib/nagios/plugins/check_load -w 15,10,5 -c 30,25,20
command[check_all_disks]=/usr/lib/nagios/plugins/check_disk -w 20 -c 10 -p /
command[check_zombie_procs]=/usr/lib/nagios/plugins/check_procs -w 5 -c 10 -s Z
command[check_procs]=/usr/lib/nagios/plugins/check_procs -w 200 -c 250
command[check_swap]=/usr/lib/nagios/plugins/check_swap -w 20 -c 10

EOF
}

restartnag()
{
service nagios-nrpe-server restart
}

genconf()
{
PGINFO=$(pg_lsclusters -h)
cat << EOF >> ${CUST}_icinga.cfg_${WORKDATE}
# Date: $WORKDATE
# $DOMAIN
# $MACHID
# $FQDN
# $LANIP
# $WANIP
# $PGINFO

define host{
        use                     cloud-host            ; Name of host template to use
        host_name            	${CUST}.xtuplecloud.com
        alias                   ${CUST}.xtuplecloud.com
        address                 ${CUST}.xtuplecloud.com
        }

define service{
        use                             generic-service         ; Name of service template to use
        host_name                      	${CUST}.xtuplecloud.com 
        service_description             Disk Space
        check_command                   check_nrpe_1arg!check_all_disks
        }

define service{
        use                             generic-service         ; Name of service template to use
        host_name                       ${CUST}.xtuplecloud.com
        service_description             Current Users
        check_command                   check_nrpe_1arg!check_users
        }

define service{
        use                             generic-service         ; Name of service template to use
        host_name                       ${CUST}.xtuplecloud.com
        service_description             Total Processes
	check_command                   check_nrpe_1arg!check_procs
       }

define service{
        use                             generic-service         ; Name of service template to use
        host_name                       ${CUST}.xtuplecloud.com 
        service_description             Current Load
	check_command                   check_nrpe_1arg!check_load
       }

define service {
	use 		generic-service
	host_name	${CUST}.xtuplecloud.com
	service_description	${CUST}.xtuplecloud.com PostgreSQL Service Database Connections
	check_command	check_postgres_connections!150!190
}

define service {
	use 		generic-service
	host_name       ${CUST}.xtuplecloud.com
	service_description	${CUST}.xtuplecloud.com PostgreSQL Service connection 
	check_command	check_postgres_connection
}

define service {
        use             generic-service
        host_name       ${CUST}.xtuplecloud.com
        service_description     ${CUST} PostgreSQL Service connection
        check_command   check_postgres_connections_port!${PGPORT}!40!50
}
EOF

}

installpkg
installcfg
genconf
restartnag

