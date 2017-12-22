#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

LOG_FILE=$(pwd)/install-$DATE.log
DATE=$(date +%Y.%m.%d-%H:%M)

log_exec() {
  "$@" | tee -a $LOG_FILE 2>&1
  RET=${PIPESTATUS[0]}
  return $RET
}

log() {
  echo "$( timestamp ) xtuple >> $@"
  echo "$( timestamp ) xtuple >> $@" >> $LOG_FILE
}

timestamp() {
  date +"%T"
}

datetime() {
  date +"%D %T"
}

log "Logging initialized. Current session will be logged to $LOG_FILE"

do_exit() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Exiting xTuple Admin Utility"
  exit 0
}

die() {
echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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

dlf() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  local URL=$1
  local WINDOWTITLE=$2
  local FILENAME=$3
  log "Downloading $URL to file $FILENAME using wget"
  wget "$URL" 2>&1 -O "$FILENAME"  | \
    stdbuf -o0 awk '/[.] +[0-9][0-9]?[0-9]?%/ { print substr($0,63,3) }' | \
    whiptail --backtitle "$( window_title )" --gauge "$WINDOWTITLE" 0 0 100;
  return ${PIPESTATUS[0]}
}

dlf_fast() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  local URL=$1
  local WINDOWTITLE=$2
  local FILENAME=$3
  log "Downloading $URL to file $FILENAME using axel"
  axel -n 5 "$URL" -o "$FILENAME" 2>&1 | \
    stdbuf -o0 awk '/[0-9][0-9]?%+/ { print substr($0,2,3) }' | \
    whiptail --backtitle "$( window_title )" --gauge "$WINDOWTITLE" 0 0 100;
  return ${PIPESTATUS[0]}
}

dlf_fast_console() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  local URL=$1
  local FILENAME=$2
  log "Downloading $URL to file $FILENAME using axel console output only"
  axel -n 5 "$URL" -o "$FILENAME" > /dev/null
}

msgbox() {
  local MSG="$1"
  log "MessageBox >> ""$MSG"
  [ $MODE = "manual" ] && whiptail --backtitle "$( window_title )" --msgbox "$MSG" 0 0 0
}

latest_version() {
  local PRODUCT="$1"
  VER=$(curl -s http://files.xtuple.org/latest_$PRODUCT)
  echo $VER
}

window_title() {
  local PWSET=Set
  if [ -z "$PGHOST" ] && [ -z "$PGPORT" ] && [ -z "$PGUSER" ] && [ -z "$PGPASSWORD" ]; then
    echo "xTuple Admin Utility v$_REV -=- Current Connection Info: Not Connected"
  else
    [ -n "$PGPASSWORD" ] || PWSET="Not Set"
    echo "xTuple Admin Utility v$_REV -=- Current Server $PGUSER@$PGHOST:$PGPORT -=- Password Is $PWSET"
  fi
}

menu_title() {
  local TITLE="$1"
  cat "$WORKDIR"/xtuple.asc
  echo "$TITLE"
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
      sudo apt-get -y install axel git whiptail unzip bzip2 wget curl build-essential libssl-dev postgresql-client-$PGVER cups python-software-properties openssl libnet-ssleay-perl libauthen-pam-perl libpam-runtime libio-pty-perl perl libavahi-compat-libdnssd-dev python xvfb jq s3cmd python-magic dialog xsltproc postgresql-common
      RET=$?
      if [ $RET -ne 0 ]; then
        msgbox "Something went wrong installing prerequisites for $DISTRO/$CODENAME. Check the log for more info. "
        do_exit
      fi

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

is_port_open() {
  local PORT=$1
  local PROTOCOL=$2

  (echo >/dev/$PROTOCOL/localhost/$PORT) &>/dev/null && return 0 || return 1
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

