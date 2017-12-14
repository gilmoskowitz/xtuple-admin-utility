#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

do_exit() {
    log "Exiting xTuple Admin Utility"
    exit 0
}

die() {
  TRAPMSG="$@"
  log $@
  exit 1
}

# catch user hitting control-c during operation, exit gracefully. 
trap ctrlc INT
ctrlc() {
  log "Breaking due to user CTRL-C"
  do_exit
}

# $1 is the URL
# $2 is the name of what is downloading to show on the window
# $3 is the output file name
dlf() {
    log "Downloading $1 to file $3 using wget"
    wget "$1" 2>&1 -O "$3"  | stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | whiptail --backtitle "$( window_title )" --gauge $2 0 0 100;
    return ${PIPESTATUS[0]}
}

# $1 is the URL
# $2 is the name of what is downloading to show on the window
# $3 is the output file name
dlf_fast() {
    log "Downloading $1 to file $3 using axel"
    axel -n 5 "$1" -o "$3" 2>&1 | stdbuf -o0 awk '/[0-9][0-9]?%+/ { print substr($0,2,3) }' | whiptail --backtitle "$( window_title )" --gauge "$2" 0 0 100;
    return ${PIPESTATUS[0]}
}

# $1 is the URL
# $3 is the output file name
dlf_fast_console() {
    log "Downloading $1 to file $2 using axel console output only"
    axel -n 5 "$1" -o "$2" > /dev/null
}

# $1 is the msg
msgbox() {
    log "MessageBox >> ""$1"
    [ $MODE = "manual" ] && whiptail --backtitle "$( window_title )" --msgbox "$1" 0 0 0
}

# $1 is the product
latest_version() {
    VER=$(curl -s http://files.xtuple.org/latest_$1)
    echo $VER
}

window_title() {
    if [ -z "$PGHOST" ] && [ -z "$PGPORT" ] && [ -z "$PGUSER" ] && [ -z "$PGPASSWORD" ]; then
        echo "xTuple Admin Utility v$_REV -=- Current Connection Info: Not Connected"
    elif [ ! -z "$PGHOST" ] && [ ! -z "$PGPORT" ] && [ ! -z "$PGUSER" ] && [ -z "$PGPASSWORD" ]; then
        echo "xTuple Admin Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is Not Set"
    else
        echo "xTuple Admin Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is Set"
    fi
}

# $1 is text to display
menu_title() {
    cat "$WORKDIR"/xtuple.asc
    echo "$1"
}

# used whenever a command needs elevated privileges as we can't always rely on sudo
runasroot() {
  if [[ $UID -eq 0 ]]; then
    "$@"
  elif sudo -v &>/dev/null && sudo -l "$@" &>/dev/null; then
    sudo -E "$@"
  else
    echo -n "root "
    su -c "$(printf '%q ' "$@")"
  fi
}

# these are both the same currently, but the structure may change eventually
# as we add more supported distros
install_prereqs() {

    case "$DISTRO" in
        "ubuntu")
                install_pg_repo
                sudo apt-get update
                sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-$PGVER cups python-software-properties openssl libnet-ssleay-perl libauthen-pam-perl libpam-runtime libio-pty-perl perl libavahi-compat-libdnssd-dev python xvfb jq s3cmd python-magic
                RET=$?
                if [ $RET -ne 0 ]; then
                    msgbox "Something went wrong installing prerequisites for $DISTRO/$CODENAME. Check the log for more info. "
                    do_exit
                fi

                # Install LE prerequsites
                source letsencrypt/installLE.sh

                # fix the background color
                sudo sed -i 's/magenta/blue/g' /etc/newt/palette.ubuntu
                ;;
        "debian")
                install_pg_repo
                sudo apt-get update
                sudo apt-get -y install python-software-properties software-properties-common xvfb
                if [ ! "$(find /etc/apt/ -name *.list | xargs cat | grep  ^[[:space:]]*deb | grep backports)" ]; then
                    sudo add-apt-repository -y "deb http://ftp.debian.org/debian $(lsb_release -cs)-backports main"
                    sudo apt-get update
                fi
                sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-$PGVER
                RET=$?
                if [ $RET -ne 0 ]; then
                    msgbox "Something went wrong installing prerequisites for $DISTRO/$CODENAME. Check the log for more info. "
                    do_exit
                fi
                ;;
         "centos")
                log "Maybe one day we will support CentOS..."
                do_exit
                ;;
        *)
        log "Shouldn't reach here! Please report this on GitHub. install_prereqs"
        do_exit
        ;;
    esac

}

install_pg_repo() {

    case "$CODENAME" in
        "trusty") ;&
        "utopic") ;&
        "wheezy") ;&
        "jessie") ;&
        "xenial")
            # check to make sure the PostgreSQL repo is already added on the system
            if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
                sudo bash -c "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
                sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
            fi
        ;;
    esac
}

# $1 is the port
# $2 is protocol
is_port_open() {

    (echo >/dev/$2/localhost/$1) &>/dev/null && return 0 || return 1

}

new_postgres_port() {
    PGPORT=$(for i in $(seq 5432 5500) $(sudo pg_lsclusters -h | awk '{print $3}') ; do echo $i; done | sort | uniq -u | head -1)
}

new_nginx_port() {
    NGINX_PORT=$(for i in $(seq 8443 8500) $(head -2 /etc/nginx/sites-available/* | grep -Po '8[0-9]{3}') ; do echo $i; done | sort | uniq -u | head -1)
}

test_connection() {
    log "Testing internet connectivity..."
    wget -q --tries=5 --timeout=10 -O - http://files.xtuple.org > /dev/null
    if [[ $? -eq 0 ]]; then
        log "Internet connectivity detected."
        return 0
    else
        log "Internet connectivity not detected."
        return 1
    fi
}

setup_sudo() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

if [[ ! -f /etc/sudoers.d/90-xtau-users ]] || ! grep -q "${DEPLOYER_NAME}" /etc/sudoers.d/90-xtau-users; then
echo "Setting up user: $DEPLOYER_NAME for sudo"
echo "You might be prompted for your password."
(echo '
# User rules for xtau

'${DEPLOYER_NAME}' ALL=(ALL) NOPASSWD:ALL'
)| sudo tee -a /etc/sudoers.d/90-xtau-users >/dev/null

else
echo "User: $DEPLOYER_NAME already setup in sudoers.d"
fi
}


# define some colors if the tty supports it
if [[ -t 1 && ! $COLOR = "NO" ]]; then
  COLOR1='\e[1;39m'
  COLOR2='\e[1;32m'
  COLOR3='\e[1;35m'
  COLOR4='\e[1;36m'
  COLOR5='\e[1;34m'
  COLOR6='\e[1;33m'
  COLOR7='\e[1;31m'
  ENDCOLOR='\e[0m' 
  S='\\'
fi


