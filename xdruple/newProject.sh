#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

# Can run it like...
# ./newProject.sh CRMACCT true dev 1

CRMACCT=$1
IS_FLYWHEEL=$2
XDENV=$3
UPDREADME=$4

XTAUHOME=../

clear

setxdvars() {
  if [[ -z ${CRMACCT} ]]; then
    echo "If you do not know it, look in dogfood."
    read -p "Enter the CRM Account Number: " CRMACCT
  fi

  if [[ -z ${IS_FLYWHEEL} ]]; then
    echo "Answer true or false"
    read -p "Is this a flywheel site? TRUE/FALSE: " IS_FLYWHEEL
  fi

  if [[ -z ${XDENV} ]]; then
    echo "Environment must be be one of: stable, RC, beta, alpha, dev"
    read -p "What kind of environment is this? " XDENV
  fi

  export CRMACCT=${CRMACCT,,}
  export IS_FLYWHEEL=${IS_FLYWHEEL,,}
  export XDENV=${XDENV,,}

  XDREPOPREFIX=xd_
  XDWORKDIR=${HOME}/xDrupleSites
  XDLOCALNAME=${XDREPOPREFIX}${CRMACCT}

  CDDREPOURL=http://satis.codedrivendrupal.com

  if [[ -f ${HOME}/.gitconfig ]]; then
    echo "Configuring Git using settings from ~/.gitconfig"
  fi

  GIT_USERNAME=$(git config --get github.name)
  if [[ -z ${GIT_USERNAME} ]]; then
    echo "We did not find a github.name for git config github.name"
    read -p "What is your First and Last Name? " GIT_USERNAME
    git config --global github.name "${GIT_USERNAME}"
    git config --global user.name "${GIT_USERNAME}"
  fi

  GIT_EMAIL=$(git config --get github.email)
  if [[ -z ${GIT_EMAIL} ]]; then
    echo "We did not find a github.email for git config user.email"
    read -p "What is your Email? " GIT_EMAIL
    git config --global github.email ${GIT_EMAIL}
    git config --global user.email ${GIT_EMAIL}
  fi

  GIT_TOKEN=$(git config --get github.token)
  if [[ -z ${GIT_TOKEN} ]]; then
    echo "You are going to need a GitHub Personal Access Token Configured."
    echo "Go to https://github.com/settings/tokens/new and get one."
    echo " "
    read -p "What is your Token? " GIT_TOKEN
    git config --global github.token ${GIT_TOKEN}
  fi

  GIT_ORGNAME=$(git config --get github.user)
  if [[ -z ${GIT_ORGNAME} ]]; then
    echo "You are going to need to configure your Github Orgname/Username"
    echo "i.e. http://github.com/GIT_ORGNAME"
    echo "As in http://github.com/xtuple does. This is usually your github username."
    echo "Mine is xtpclark, as in http://github.com/xtpclark"
    read -p "What is your Github username/orgname? " GIT_ORGNAME
    git config --global github.user ${GIT_ORGNAME}
  fi

  GITXDDIR=xtuple/xdruple-drupal
  ORG_GITNAME=${XDREPOPREFIX}${CRMACCT}
  ORG_GITREPO=${XDREPOPREFIX}${CRMACCT}.git
  ORG_GITBRANCH=${XDENV} # Not used currently. We do tag these though.
  ORG_GITDESC="xDruple Template for ${CRMACCT}"

  XDBASE=${XDWORKDIR}/${XDLOCALNAME}
}

createdirs() {
  if [[ -e ${XDBASE} ]]; then
    echo "Path ${XDBASE} already exists, not messing with it! EXITING!"
    exit 0
  else
    mkdir -p ${XDBASE}
  fi
}

switchdir() {
  cd ${XDBASE}
}


createxdruplerepo() {
  if [[ -z ${XDENV} || -z ${CDDREPOURL} || -z ${GITXDDIR} || -z ${XDBASE} ]]; then
    echo "Composer is missing some information."
    echo "Check your settings in setxdvars!"
    echo "I got: XDENV=${XDENV} CDDREPOURL=${CDDREPOURL} GITXDDIR=${GITXDDIR} XDBASE=${XDBASE}"
  else
    echo "OK - I got: XDENV=${XDENV} CDDREPOURL=${CDDREPOURL} GITXDDIR=${GITXDDIR} XDBASE=${XDBASE}"
    composer create-project --stability ${XDENV} --no-interaction --repository-url=${CDDREPOURL} ${GITXDDIR} ${XDBASE}
    RET=$?
    if [ $RET -ne 0 ]; then
      echo "composer create-project failed for some reason. createxdruplerepo()"
      exit 0
    fi
  fi
}

updatedist() {
  SETFLAG=''

  if [[ ${IS_FLYWHEEL,,} == "true" ]]; then
    SETFLAG='-f'
  fi

  switchdir
  ./console.php update:distributions ${SETFLAG}
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "./console.php update:distributions failed for some reason. updatedist()"
    exit 0
  fi
}

setupsymlinks() {
  switchdir
  ./console.php install:prepare:directories
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "./console.php install:prepare:directories failed for some reason. setuplsymlinks()"
    exit 0
  fi
}


updatereadme() {
  UPDREADME=$(git config --get xtuple.updatereadme)
  if [[ ${UPDREADME} ]]; then

    if [[ -f ~/.selected_editor ]]; then
      source ${HOME}/.selected_editor
    else
      select-editor
    fi

    source ${HOME}/.selected_editor
    export EDITOR=$SELECTED_EDITOR

    switchdir

    ${EDITOR} README.md
  fi

  echo "Not updating README.md"
}

preparetheme() {
  true
}

git_init() {
  switchdir
  git config --global user.name "${GIT_USERNAME}"
  git config --global user.email ${GIT_EMAIL}

  git init
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "git_init() failed for some reason."
    exit 0
  fi
}

git_createrepo() {
  GITHUBUSER=${GIT_ORGNAME}
  curl https://"${GIT_TOKEN}":x-oauth-basic@api.github.com/user/repos --data "{\"name\": \"${ORG_GITREPO}\", \"description\": \"${ORG_GITDESC}\", \"private\": true, \"has_issues\": true, \"has_downloads\": true, \"has_wiki\": false}" -o GITCREATE.log
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "git_createrepo() failed for some reason."
    exit 0
  fi
}

git_add() {
  switchdir
  git add .
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "git_add() failed for some reason."
    exit 0
  fi
}

git_commit() {
  switchdir
  git commit -m "${CRMACCT}: First commit"
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "git_commit() failed for some reason."
    exit 0
  fi
}

git_addremote() {
  switchdir
  git remote add origin https://"$GIT_TOKEN":x-oauth-basic@github.com/${GIT_ORGNAME}/${ORG_GITREPO}
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "git_addremote() failed for some reason."
    exit 0
  fi
}

git_push() {
  switchdir
  git push origin master
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "git_push() failed for some reason."
    exit 0
  fi
}

setxdvars
createdirs
createxdruplerepo
updatedist
setupsymlinks

updatereadme

preparetheme

git_init
git_add
git_commit
git_createrepo
git_addremote
git_push


cat << EOF >> ${CRMACCT}.log
CRMACCT=${CRMACCT}
XDENV=${XDENV}
CDDREPOURL=${CDDREPOURL}
GITXDDIR=${GITXDDIR}
XDBASE=${XDBASE}
Check out your repo on https://github.com/${GIT_ORGNAME}/${ORG_GITREPO}
EOF

clear
cat ${CRMACCT}.log
echo "All done!"
