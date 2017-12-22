#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

[ -n "$(typeset -F -p log)" ] || source ${BUILD_WORKING:-.}/common.sh

provision_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  log "Opened provisioning menu"

  local ACTION
  ACTION=$(whiptail --backtitle "$( window_title )" --menu "Select Action" 0 0 7 --ok-button "Select" --cancel-button "Cancel" \
          "1" "Install non-web-enabled xTuple" \
          "2" "Install web-enabled xTuple" \
          3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return 0
  elif [ $ACTION = "1" ]; then
    log_exec install_postgresql $PGVER
    
    get_cluster_list

    if [ -n "$CLUSTERS" ]; then
      set_database_info_select
    else
      msgbox "Return to main menu and select other option"
      main_menu
    fi
  fi
  msgbox "Install Complete"

  return 0
}
