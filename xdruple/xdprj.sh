#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

DATE=$(date +%Y.%m.%d-%H.%M)
source ../logging.sh
source xdprj.fun

#CRMACCT=$1
#IS_FLYWHEEL=$2
#XDENV=$3
#UPDREADME=$4


clear

setxdvars
echo "log: Set xdvars"
createdirs
echo "log: Created dirs"
createxdruplerepo
echo "log: createxdruplerepo"
updatedist
echo "log: updatedist"
setupsymlinks
echo "log: setupsymlinks"
updatereadme
echo "log: updatereadme"
preparetheme
echo "log: preparetheme"
git_init
git_add
git_commit
git_createrepo
git_addremote
git_push

log_xd ""
log_xd "CRMACCT=${CRMACCT}"
log_xd "XDENV=${XDENV}"
log_xd "CDDREPOURL=${CDDREPOURL}"
log_xd "GITXDDIR=${GITXDDIR}"
log_xd "XDBASE=${XDBASE}"
log_xd "Check out your repo on https://github.com/${GIT_ORGNAME}/${ORG_GITREPO}"

echo "All done!"

