#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

[ -n "$(typeset -F -p log)" ] || source ${BUILD_WORKING:-.}/common.sh

nginx_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  log "Opened nginx menu"

  while true; do
    NGM=$(whiptail --backtitle "xTuple Utility v$_REV" --menu "$( menu_title nginx\ Menu )" 0 0 4 --cancel-button "Cancel" --ok-button "Select" \
        "1" "Install nginx" \
        "2" "Configure nginx" \
        "3" "Remove nginx" \
        "4" "Return to main menu" \
        3>&1 1>&2 2>&3)

    RET=$?

    if [ $RET -ne 0 ]; then
      break
    else
      case "$NGM" in
        "1") log_exec install_nginx ;;
        "2") log_exec configure_nginx ;;
        "3") log_exec remove_nginx ;;
        "4") break ;;
          *) msgbox "How did you get here? nginx_menu $NGM" && break ;;
      esac
    fi
  done
}

install_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  log "Installing nginx"

  log_exec sudo apt-get -y install nginx
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Nginx failed to install."
  fi
  return $RET
}

# Confirm or set all nginx related variables interactively
# Run this before configure_nginx if interactive
# Set all variables if headless/automatic
nginx_prompt() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if [ "$MODE" = "auto" ]; then
      return 127
  fi

  NGINX_HOSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Host name (the domain comes next)" 8 60 "$NGINX_HOSTNAME" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  NGINX_DOMAIN=$(whiptail --backtitle "$( window_title )" --inputbox "Domain name (example.com)" 8 60 "$NGINX_DOMAIN" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  NGINX_SITE=$(whiptail --backtitle "$( window_title )" --inputbox "Site name. This will be the name of the config file." 8 60 "$NGINX_SITE" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  if (whiptail --title "Generate SSL key" --yesno "Would you like to generate a self signed SSL certificate and key?" 10 60) then
    GEN_SSL=true
  else
    GEN_SSL=false
  fi

  NGINX_CERT=$(whiptail --backtitle "$( window_title )" --inputbox "SSL Certificate file path" 8 60 "/etc/xtuple/ssl/$NGINX_SITE.crt" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  NGINX_KEY=$(whiptail --backtitle "$( window_title )" --inputbox "SSL Key file path" 8 60 "/etc/xtuple/ssl/$NGINX_SITE.key" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  new_nginx_port
  NGINX_PORT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter port number.\n\nUsed Ports:\n$(head -2 /etc/nginx/sites-available/* | grep -Po '8[0-9]{3}')" 18 60 "$NGINX_PORT" 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi
}

# run nginx_prompt first if interactive
#  the return value should be 0 before continuing
# set variables first if headless/automatic
# variables:
#   NGINX_HOSTNAME  - subdomain that points to the specific web client
#   NGINX_DOMAIN    - domain name of the server
#   NGINX_SITE      - nginx site name which is also the web client instance name
#   NGINX_CERT      - website certificate which should be per site and a separate file in /etc/xtuple/ssl
#   NGINX_KEY       - website key with the same requirements
#   NGINX_PORT      - nginx port to listen to
configure_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  log "Configuring nginx"

  log "Removing nginx site default"
  [[ -e /etc/nginx/sites-available/default ]] && sudo rm /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>&1 >/dev/null

  log "Creating site file"
  sudo cp templates/nginx-site /etc/nginx/sites-available/$NGINX_SITE
  sudo sed -i -e "s#DOMAINNAME#$NGINX_DOMAIN#" -e "s#HOSTNAME#$NGINX_HOSTNAME#" /etc/nginx/sites-available/$NGINX_SITE
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Error configuring nginx.  Check site file in /etc/nginx/sites-available"
    return $RET
  fi

  log "Enabling site"
  sudo ln -s /etc/nginx/sites-available/$NGINX_SITE /etc/nginx/sites-enabled/$NGINX_SITE

  sudo mkdir -p /etc/xtuple/ssl
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "SSL DIR creation failed."
    return $RET
  fi

  # LetsEncrypt will go around here
  log "Generating certificate"
  sudo openssl req -x509 -newkey rsa:4096 -subj /CN=${NGINX_HOSTNAME}.${NGINX_DOMAIN} -days 365 -nodes -keyout $NGINX_KEY -out $NGINX_CERT
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "SSL Certificate creation failed."
    return $RET
  fi

  sudo sed -i -e 's#SERVER_CRT#'$NGINX_CERT'#g' -e 's#SERVER_KEY#'$NGINX_KEY'#g' /etc/nginx/sites-available/$NGINX_SITE
  sudo sed -i 's#MWCPORT#'$NGINX_PORT'#g' /etc/nginx/sites-available/${NGINX_SITE}

  log "Reloading nginx configuration"
  sudo nginx -s reload
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Reloading nginx configuration failed. Check the log file for errors."
    return $RET
  else
    msgbox "nginx installed and configured successfully."
  fi
}

remove_nginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  if (whiptail --title "Are you sure?" --yesno "Uninstall nginx?" --yes-button "Yes" --no-button "No" 10 60) then
    log "Uninstalling nginx..."
    log_exec sudo apt-get -y remove nginx
    RET=$?
    return $RET
  else
    return 0
  fi
}
