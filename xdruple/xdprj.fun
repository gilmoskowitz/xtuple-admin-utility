#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

IS_FLYWHEEL=TRUE

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

if [[ -f ${HOME}/.gitconfig ]]; then
echo "Configuring Git using settings from ~/.gitconfig"
fi

XDREPOPREFIX=$(git config --get xdruple.xdrepoprefix)
if [[ -z ${XDREPOPREFIX} ]]; then
XDREPOPREFIX=xd_
git config --global xdruple.xdrepoprefix "${XDREPOPREFIX}"
fi

XDWORKDIR=$(git config --get xdruple.xdworkdir)
if [[ -z ${XDWORKDIR} ]]; then
XDWORKDIR=${HOME}/xDrupleSites
git config --global xdruple.xdworkdir "${XDWORKDIR}"
fi

XDLOCALNAME=${XDREPOPREFIX}${CRMACCT}

CDDREPOURL=$(git config --get xdruple.cddrepourl)
if [[ -z ${CDDREPOURL} ]]; then
CDDREPOURL=http://satis.codedrivendrupal.com
git config --global xdruple.cddrepourl "${CDDREPOURL}"
fi

GITXDDIR=$(git config --get xdruple.gitxddir)
if [[ -z ${GITXDDIR} ]]; then
GITXDDIR=xtuple/xdruple-drupal
git config --global xdruple.gitxddir "${GITXDDIR}"
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

GIT_USER=$(git config --get github.user)
if [[ -z ${GIT_USER} ]]; then
echo "You are going to need to configure your Github Orgname/Username"
echo "i.e. http://github.com/GIT_ORGNAME"
echo "As in http://github.com/xtuple does. This is usually your github username."
echo "Mine is xtpclark, as in http://github.com/xtpclark"
read -p "What is your Github username/orgname? " GIT_USER
git config --global github.user ${GIT_USER}
fi

GIT_ORGNAME=$(git config --get github.org)
if [[ -z ${GIT_ORGNAME} ]]; then
echo "You are going to need to configure your Github Orgname"
echo "i.e. http://github.com/GIT_ORGNAME"
echo "As in http://github.com/xtuple does. This is usually who you are working for..."
echo "I work for xtuple, as in http://github.com/xtuple"
read -p "What is your Github username/orgname? " GIT_ORGNAME
git config --global github.org ${GIT_ORGNAME}
fi

ORG_GITNAME=${XDREPOPREFIX}${CRMACCT}
ORG_GITREPO=${XDREPOPREFIX}${CRMACCT}.git
ORG_GITBRANCH=${XDENV} # Not used currently. We do tag these though.
ORG_GITDESC="${CRMACCT^} xTupleCommerce Project"

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

log_xd_exec composer create-project --stability ${XDENV} --no-interaction --repository-url=${CDDREPOURL} ${GITXDDIR} ${XDBASE}
RET=$?
    if [ $RET -ne 0 ]; then
        echo "composer create-project failed for some reason. createxdruplerepo()"
        exit 0
    fi

echo "Ran: composer create-project --stability ${XDENV} --no-interaction --repository-url=${CDDREPOURL} ${GITXDDIR} ${XDBASE} "


fi

}


updatedist() {
SETFLAG=''

if [[ ${IS_FLYWHEEL,,} = "true" ]]; then

SETFLAG='-f'
READMENOTE="Flywheel Application"
else
READMENOTE="Custom Application"

fi

switchdir
echo "FLAGGING ./console.php update:distributions ${SETFLAG}"
./console.php update:distributions -f
RET=$?
    if [ $RET -ne 0 ]; then
        echo "./console.php update:distributions ${SETFLAG} failed for some reason. updatedist()"
        exit 0
    fi

echo "Ran: ./console.php update:distributions ${SETFLAG}"
cp ${XDBASE}/config/application.php.dist ${XDBASE}/config/application.php
echo "Ran: cp ${XDBASE}/config/application.php.dist ${XDBASE}/config/application.php"

}

setupsymlinks() {

switchdir
log_xd_exec ./console.php install:prepare:directories
RET=$?
    if [ $RET -ne 0 ]; then
        echo "./console.php install:prepare:directories failed for some reason. setuplsymlinks()"
        exit 0
    fi

echo "Ran: ./console.php install:prepare:directories"

}


updatereadmeold() {
UPDREADME=$(git config --get xdruple.updatereadme)
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

updatereadme() {
switchdir
# $({project_title}) (”Matzka”), $({project}) (”matzka”}, $({project_repo}) (”xd_matzka”)
# -e "s/Project/${CRMACCT^}/g" \

sed -i \
-e "s/{project_repo}.git/${ORG_GITREPO}/g" \
-e "s/{project}.xd/${XDLOCALNAME}.xd/g" \
-e "s/project.xd/${XDLOCALNAME}.xd/g" \
-e "s/# {project_title}/# ${CRMACCT^} ${READMENOTE} Drupal Project/g" \
-e "s/{project_title}/${CRMACCT^}/g" \
-e "s/{project}/${CRMACCT,,}/g" README.md
RET=$?
    if [ $RET -ne 0 ]; then
        echo "updatereadme() in ${XDBASE} failed for some reason."
        exit 0
else
echo "Edited ${XDBASE}/README.md"
     fi

}

preparetheme() {
true
}

git_init() {
switchdir
#git config --global user.name "${GIT_USERNAME}"
#git config --global user.email ${GIT_EMAIL}

log_xd_exec git init
RET=$?
    if [ $RET -ne 0 ]; then
        echo "git_init() failed for some reason."
        exit 0
     fi

}

git_createrepo() {
log_xd_exec curl https://"${GIT_TOKEN}":x-oauth-basic@api.github.com/orgs/${GIT_ORGNAME}/repos --data "{\"name\": \"${ORG_GITREPO}\", \"description\": \"${ORG_GITDESC}\", \"private\": true, \"has_issues\": true, \"has_downloads\": true, \"has_wiki\": false}"

# curl https://"${GIT_TOKEN}":x-oauth-basic@api.github.com/user/repos --data "{\"name\": \"${ORG_GITREPO}\", \"description\": \"${ORG_GITDESC}\", \"private\": true, \"has_issues\": true, \"has_downloads\": true, \"has_wiki\": false}" -o GITCREATE.log
RET=$?
    if [ $RET -ne 0 ]; then
        echo "git_createrepo() failed for some reason."
        exit 0
    fi
# echo "Ran: curl https://"${GIT_TOKEN}":x-oauth-basic@api.github.com/orgs/${GIT_ORGNAME}/repos --data "{\"name\": \"${ORG_GITREPO}\", \"description\": \"${ORG_GITDESC}\", \"private\": true, \"has_issues\": true, \"has_downloads\": true, \"has_wiki\": false}"

}


git_add() {
switchdir
log_xd_exec git add .
RET=$?
    if [ $RET -ne 0 ]; then
        echo "git_add() failed for some reason."
        exit 0
    fi

}

git_commit() {
switchdir
log_xd_exec git commit -m "${CRMACCT}: First commit"
RET=$?
    if [ $RET -ne 0 ]; then
        echo "git_commit() failed for some reason."
        exit 0
    fi

}


git_addremote() {
switchdir
log_xd_exec git remote add origin https://"$GIT_TOKEN":x-oauth-basic@github.com/${GIT_ORGNAME}/${ORG_GITREPO}
RET=$?
    if [ $RET -ne 0 ]; then
        echo "git_addremote() failed for some reason."
        exit 0
    fi

}

git_push() {
switchdir
log_xd_exec git push origin master
RET=$?
    if [ $RET -ne 0 ]; then
        echo "git_push() failed for some reason."
        exit 0
    fi
}




