#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

ssh_setup(){
log "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

# This is added so composer doesn't ask for auth during the process.
if [[ -e ~/.ssh/config ]]; then

log "Found SSH config"

SSHFILE=~/.ssh/config

declare file=${SSHFILE}
declare regex="\s+
#Added by xTau
Host github.com
HostName github.com
StrictHostKeyChecking no\s+"

declare file_content=$( cat "${file}" )
if [[ " $file_content " =~ $regex ]]
    then
log "SSH Config looks good"
else
cat << EOF >> ~/.ssh/config

#Added by xTau
Host github.com
HostName github.com
StrictHostKeyChecking no

EOF

fi

else
log "Creating ~/.ssh/config"

if [ ! -d ~/.ssh  ]; then
log_exec sudo mkdir -p ~/.ssh

else
cat << EOF >> ~/.ssh/config

#Added by xTau
Host github.com
HostName github.com
StrictHostKeyChecking no

EOF
fi

fi

}


get_composer_token()
{
source  xdruple/functions/gitvars.fun
loadadmin_gitconfig

log "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
if type "composer" > /dev/null; then
AUTHKEYS+=$(composer config -g --list | grep '\[github-oauth.github.com\]' | cut -d ' ' -f2)
COMPOSER_HOME=$(composer config -g --list | grep '\[home\]' | cut -d ' ' -f2)

else
whiptail --backtitle "$( window_title )" --yesno "Composer not found. Do you want to install it?" 8 60 --cancel-button "Exit" --ok-button "Select"  3>&1 1>&2 2>&3
install_composer

fi
}

generate_github_token()
{
source  xdruple/functions/gitvars.fun
loadadmin_gitconfig

log "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

#GIT_TOKEN=$(git config --get github.token)
#if [[ -z ${GIT_TOKEN} ]]; then
#echo "You are going to need a GitHub Personal Access Token Configured."
#echo "Go to https://github.com/settings/tokens/new and get one."
#echo " "
#read -p "What is your Token? " GIT_TOKEN
#fi


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
        GITHUB_TOKEN=$(jq --raw-output '.token | select(length > 0)' GITHUB_TOKEN_${WORKDATE}.log)
        OAMSG=$(jq --raw-output '.' GITHUB_TOKEN_${WORKDATE}.log)

            if [[ -z "${GITHUB_TOKEN}" ]]; then
            whiptail --backtitle "$( window_title )" --msgbox "Error creating your token. ${OAMSG}" 8 60 3>&1 1>&2 2>&3
            break
            else
	    GITHUB_TOKEN=$(git config --global github.token ${GITHUB_TOKEN})
            whiptail --backtitle "$( window_title )" --msgbox "Your GitHub Personal Access token is: ${GITHUB_TOKEN}.\n\nMaintain your tokens at:\nhttps://github.com/settings/tokens\n\nToken written to ${HOME}/.gitconfig" 16 60 3>&1 1>&2 2>&3

            export GITHUB_TOKEN=${GITHUB_TOKEN}
            get_composer_token
            fi
            whiptail --backtitle "$( window_title )" --msgbox "Maintain your Github Personal Access Tokens at: https://github.com/settings/tokens" 8 60 3>&1 1>&2 2>&3
 fi

else
            if [[ ${GITHUB_TOKEN} ]]; then
            whiptail --backtitle "$( window_title )" --msgbox "Your GitHub Personal Access token is: ${GITHUB_TOKEN}.\n\nMaintain your tokens at:\nhttps://github.com/settings/tokens\n\nToken written to ${HOME}/.gitconfig" 16 60 3>&1 1>&2 2>&3

            log "Your GitHub Personal Access token is: ${GITHUB_TOKEN}"

	    GITHUB_TOKEN=$(git config --global github.token ${GITHUB_TOKEN})
            export GITHUB_TOKEN=${GITHUB_TOKEN}
            get_composer_token

	    else
            whiptail --backtitle "$( window_title )" --msgbox "Not sure what happened, but we don't know about a token..." 8 60 3>&1 1>&2 2>&3
	   fi

fi
}

ssh_setup
