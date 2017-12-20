#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

DATE=$(date +%Y.%m.%d-%H:%M)
export _REV="1.0"
export WORKDIR=$(pwd)
export MODE="manual"

source config.sh
source common.sh

mkdir -p $DATABASEDIR
mkdir -p $BACKUPDIR

setup_sudo

# process command line arguments
# start with :, which tells it to be silent about errors
# a doesn't require an argument, so it doesn't have a : after it
# d does require an argument, so it is indicated by putting a : after the d, and so on
while getopts ":acd:mip:n:H:D:qhx:t:-:" opt; do
  case $opt in
    a)
        INSTALLALL=true
        ;;
    d)
        DATABASE=$OPTARG
        log "Database name set to $DATABASE via command line argument -d"
        ;;
    m)
        MODE="auto"
        ;;
    p)
        PGVER=$OPTARG
        log "PostgreSQL Version set to $PGVER via command line argument -p"
        ;;
    H)
        # Hostname
        NGINX_HOSTNAME=$OPTARG
        log "NGINX hostname set to $NGINX_HOSTNAME via command line argument -H"
        ;;
    D)
        # Domain
        NGINX_DOMAIN=$OPTARG
        log "NGINX domain set to $NGINX_DOMAIN via command line argument -D"
        ;;
    q)
        # that is our cue to build the Qt development environment
        BUILDQT=true
        log "Building and installing Qt at the behest of -q"
        ;;
    x)
        # Use a specific version of xTuple (applies to web client and db)
        DBVERSION=$OPTARG
        DATABASE=${DBTYPE}${DBVERSION//./}
        log "xTuple MWC Version set to $DBVERSION via command line argument -x"
        ;;
    t)
        # Specify the type of database to grab (demo/quickstart/empty)
        DBTYPE=$OPTARG
        log "xTuple Database Type set to $DBTYPE via command line argument -x"
        ;;
    h)
        echo "Usage: xtuple-utility [OPTION]"
        echo "$( menu_title )"
        echo "To get an interactive menu run xtuple-utility.sh with no arguments"
        echo ""
        echo -e "  -h\tShow this message"
        echo -e "  -a\tInstall all (PostgreSQL (currently $( latest_version pg )), demo database (currently $( latest_version db )) and web client (currently $( latest_version db )))"
        echo -e "  -d\tSpecify database name to create"
        echo -e "  -p\tOverride PostgreSQL version"
        echo -e "  -q\tBuild and Install Qt (currently $( latest_version qt_sdk ))"
        echo -e "  -n\tOverride instance name"
        echo -e "  -H\tSet NGINX hostname"
        echo -e "  -D\tSet NGINX domain"
        echo -e "  -x\tOverride xTuple version (applies to web client and database)"
        echo -e "  -t\tSpecify the type of database to grab (demo/quickstart/empty)"
        exit 0;
        ;;
    \?)
        log "Invalid option: -$OPTARG"
        exit 1;
        ;;
    :)
        log "Option -$OPTARG requires an argument."
        exit 1
        ;;
  esac
done

if [ $(uname -m) != "x86_64" ]; then
  log "You must run this on a 64bit server only"
  do_exit
fi

log "Starting xTuple Admin Utility..."

log "Checking for sudo..."
if ! which sudo > /dev/null ; then
  log "Please install sudo and grant yourself access to sudo:"
  log "   # apt-get install sudo"
  log "   # addgroup $USER sudo"
  exit 1
fi

test_connection
RET=$?
if [ $RET -ne 0 ]; then
  log "I can't seem to tell if you have internet access or not. Please check that you have internet connectivity and that http://files.xtuple.org is online.  "
  do_exit
fi

# check what distro we are running.
_DISTRO=$(lsb_release -i -s)
_CODENAME=$(lsb_release -c -s)
case "$_DISTRO" in
    "Ubuntu")
        export DISTRO="ubuntu"
        export CODENAME=$_CODENAME
        case "$_CODENAME" in
            "trusty") ;;
            "utopic") ;;
            "vivid") ;;
            "xenial") ;;
            *) log "We currently only support Ubuntu 14.04 LTS, 14.10, 15.04, and 16.04 LTS. Current release: $(lsb_release -r -s)"
               do_exit
               ;;
        esac
        ;;
    "Debian")
        export DISTRO="debian"
        export CODENAME=$_CODENAME
        case "$_CODENAME" in
            "wheezy") ;;
            "jessie") ;;
            *) log "We currently only support Debian 7 and 8 Current release: $(lsb_release -r -s)"
               do_exit
               ;;
        esac
        ;;
    "CentOS")
        log "Maybe one day we will support CentOS..."
        do_exit
        ;;
    *)
        log "We do not currently support your distribution."
        log "Currently Supported: Ubuntu or Debian"
        log "distro info: "
        lsb_release -a
        do_exit
        ;;
esac

# Load the rest of the scripts
source postgresql.sh
source database.sh
source provision.sh
source nginx.sh
source mobileclient.sh
source openrpt.sh
source devenv.sh
source conman.sh
source tokenmanagement.sh

# kind of hard to build whiptail menus without whiptail installed
log "Installing pre-requisite packages..."
if [[ ! -f .already_ran_update ]]; then
  install_prereqs
  touch .already_ran_update
else
  log ".already_ran_update exists - skipping."
  log "Remove the file if you want apt-get to update the system"
fi

# if we were given command line options for installation process them now
if [ $INSTALLALL ]; then
  log "Executing full provision..."
  MODE="auto"

  DBVERSION="${DBVERSION:-4.10.1}"
  EDITION="${EDITION:-demo}"
  DATABASE="${DATABASE:-xtuple}"
  MWCNAME="${MWCNAME:-xtuple-web}"
  PGPORT=5432
  PGUSER=postgres

  NGINX_HOSTNAME="${NGINX_HOSTNAME:-myhost}"
  NGINX_DOMAIN="${NGINX_DOMAIN:-mydomain.com}"

  install_postgresql "$PGVER"
  #drop_cluster $PGVER main auto
  provision_cluster "$PGVER" "${POSTNAME:-xtuple}" 5432 "$LANG" "--start-conf=auto"
  download_database "$DATABASEDIR/$EDITION_$DBVERSION.backup" "$DBVERSION" "$EDITION"
  restore_database "$DATABASEDIR/$EDITION_$DBVERSION.backup" "$DATABASE"
  log_exec rm -f "$WORKDIR/tmp.backup{,.md5sum}"
  install_mwc "$DBVERSION" "v$DBVERSION" "$MWCNAME" false "$DATABASE"
  install_nginx
  log_exec sudo mkdir -p /etc/xtuple/$DBVERSION/$MWCNAME/ssl/
  configure_nginx "$NGINX_HOSTNAME" "$NGINX_DOMAIN" "$MWCNAME" true /etc/xtuple/$DBVERSION/$MWCNAME/ssl/server.{crt,key} 8443
  setup_webprint
fi

# if we're supposed to build Qt, lets do that before anything else because it takes *FOREVER*
if [ $BUILDQT ]; then
  log "Building and installing Qt5 from source"
  install_dev_prereqs
  build_qt5
fi

# It is okay to run them both, but if either one runs we want to exit after as these
# are expected to be used headlessly.
if [ $BUILDQT ] || [ $INSTALLALL ]; then
  do_exit
fi

# we load mainmenu.sh last since it calls its menu once it builds it
# and this is the initial interface for the user
source mainmenu.sh
