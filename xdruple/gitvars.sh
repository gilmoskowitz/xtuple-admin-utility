#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

source functions/gitvars.fun
CRMACCT=$1

if [[ -z ${CRMACCT} ]]; then
echo "Need to set a CRMACCT"
exit 0
else
loadcrm_gitconfig
checkcrm_gitconfig
fi

