#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

[ -n "$(typeset -F -p log)" ]                   || source ${BUILD_WORKING}/common.sh

main_menu() {
  log "Opened main menu"

  while true; do

    CC=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Main\ Menu)" 0 0 1 --cancel-button "Exit" --ok-button "Select" \
        "1" "Quick Install" \
        "2" "PostgreSQL Maintenance" \
        "3" "Database Maintenance" \
        "4" "Development Environment Setup" \
        "5" "SSH Connection Manager" \
        "6" "Generate Github Token" \
        "7" "xTupleCommerce Bundle" \
        3>&1 1>&2 2>&3)
    
    RET=$?
    
    if [ $RET -ne 0 ]; then
        do_exit
    else
      case "$CC" in
        "1") provision_menu ;;
        "2") postgresql_menu ;;
        "3") database_menu ;;
        "4") dev_menu ;;
        "5") selectServer;;
        "6") generate_github_token;;
        "7") source CreatePackages.sh build_xtau;;
        *) msgbox "Don't know how you got here! Please report on GitHub >> mainmenu" && do_exit ;;
      esac
    fi
  done
}

main_menu
