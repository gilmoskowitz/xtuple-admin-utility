#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

setthevars()
{

if [[ -z ${CRMACCT} ]]; then
echo "Need to set a CRMACCT"
exit0
fi

git config --global ${CRMACCT,,}env.commerceauthnetaimlogin YOUR_COMMERCE_AUTHNET_AIM_LOGINSOMETHING
git config --global ${CRMACCT,,}env.commerceauthnetaimtransactionkey YOUR_COMMERCE_AUTHNET_AIM_TRANSACTION_KEY
git config --global ${CRMACCT,,}env.upsaccountid YOUR_UPS_ACCOUNT_ID
git config --global ${CRMACCT,,}env.upsaccesskey YOUR_UPS_ACCESS_KEY
git config --global ${CRMACCT,,}env.upsuserid YOUR_UPS_USER_ID
git config --global ${CRMACCT,,}env.upspassword YOUR_UPS_PASSWORD
git config --global ${CRMACCT,,}env.upspickupschedule DAILY_PICKUP
git config --global ${CRMACCT,,}env.fedexbeta TRUE
git config --global ${CRMACCT,,}env.fedexkey YOUR_FEDEX_KEY
git config --global ${CRMACCT,,}env.fedexpassword YOUR_FEDEX_PASSWORD
git config --global ${CRMACCT,,}env.fedexaccountnumber YOUR_FEDEX_ACCOUNT
git config --global ${CRMACCT,,}env.fedexmeternumber YOUR_METER_NUMBER


PHPVARSLIST=$(git config --global -l | grep ${CRMACCT,,}env | cut -d . -f2)

for PHPVAR in ${PHPVARSLIST}; do
export ${PHPVAR}
done

}

