#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

[ -n "$(typeset -F -p log)" ] || source ${BUILD_WORKING:-.}/common.sh

ssh_setup() {
  log "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local SSHCONFIG="
#Added by xTau
Host github.com
HostName github.com
StrictHostKeyChecking no"

  # This is added so composer doesn't ask for auth during the process.
  local SSHFILE="$HOME/.ssh/config"
  local MUSTCREATE=true
  log_exec mkdir -p $(dirname $SSHFILE)
  if [[ -e "$SSHFILE" ]]; then
    log "Found SSH config"
    local file_content=$( cat "${SSHFILE}" )

    if [[ " $file_content " =~ "$SSHCONFIG" ]]; then
      MUSTCREATE=false
      log "SSH Config looks good"
    fi
  fi
  if $MUSTCREATE ; then
    log "Creating $SSHFILE"
    if [ ! -d $(dirname $SSHFILE)  ]; then
      log_exec sudo mkdir -p $(dirname $SSHFILE)
    fi
    echo "$SSHCONFIG" >> $SSHFILE
  fi
}

get_composer_token() {
  log "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  source  functions/setup.fun
  loadadmin_gitconfig

  if type "composer" > /dev/null; then
    AUTHKEYS+=$(composer config -g --list | grep '\[github-oauth.github.com\]' | cut -d ' ' -f2)
    COMPOSER_HOME=$(composer config -g --list | grep '\[home\]' | cut -d ' ' -f2)
  else
    whiptail --backtitle "$( window_title )" --yesno "Composer not found. Do you want to install it?" 8 60 --cancel-button "Exit" --ok-button "Select"  3>&1 1>&2 2>&3
    install_composer
  fi
}

generate_github_token() {
  log "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  source  functions/setup.fun
  loadadmin_gitconfig

  GITHUB_TOKEN=$(git config --get github.token)
  if [[ -z ${GITHUB_TOKEN} ]]; then
    if (whiptail --title "GitHub Personal Access Token" --yesno "Would you like to setup your GitHub Personal Access Token?" 10 60) then
      log "Creating GitHub Personal Access Token"

      GITHUBNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter your GitHub username" 8 60 3>&1 1>&2 2>&3)
      RET=$?
      if [ $RET -ne 0 ]; then
        return $RET
      fi

      GITHUBPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter your GitHub password" 8 60 3>&1 1>&2 2>&3)
      RET=$?
      if [ $RET -ne 0 ]; then
        return $RET
      fi

      log "Generating your Github token."
      WORKDATE=$(date "+%m%d%Y_%s")

      curl https://api.github.com/authorizations --user ${GITHUBNAME}:${GITHUBPASS} --data '{"scopes":["user","read:org","repo","public_repo"],"note":"Added Via xTau '${WORKDATE}'"}' -o GITHUB_TOKEN_${WORKDATE}.log
      export GITHUB_TOKEN=$(jq --raw-output '.token | select(length > 0)' GITHUB_TOKEN_${WORKDATE}.log)
      OAMSG=$(jq --raw-output '.' GITHUB_TOKEN_${WORKDATE}.log)

      if [[ -z "${GITHUB_TOKEN}" ]]; then
        whiptail --backtitle "$( window_title )" --msgbox "Error creating your token. ${OAMSG}" 8 60 3>&1 1>&2 2>&3
        break
      else
        git config --global github.token ${GITHUB_TOKEN}
        whiptail --backtitle "$( window_title )" --msgbox "Your GitHub Personal Access token is: ${GITHUB_TOKEN}.\n\nMaintain your tokens at:\nhttps://github.com/settings/tokens\n\nToken written to ${HOME}/.gitconfig" 16 60 3>&1 1>&2 2>&3

        get_composer_token
      fi
      whiptail --backtitle "$( window_title )" --msgbox "Maintain your Github Personal Access Tokens at: https://github.com/settings/tokens" 8 60 3>&1 1>&2 2>&3
    fi
  elif [[ ${GITHUB_TOKEN} ]]; then
    whiptail --backtitle "$( window_title )" --msgbox "Your GitHub Personal Access token is: ${GITHUB_TOKEN}.\n\nMaintain your tokens at:\nhttps://github.com/settings/tokens\n\nToken written to ${HOME}/.gitconfig" 16 60 3>&1 1>&2 2>&3

    log "Your GitHub Personal Access token is: ${GITHUB_TOKEN}"

    export GITHUB_TOKEN=$(git config --global github.token ${GITHUB_TOKEN})
    get_composer_token

  else
    whiptail --backtitle "$( window_title )" --msgbox "Not sure what happened, but we don't know about a token..." 8 60 3>&1 1>&2 2>&3
  fi
}

ssh_setup
