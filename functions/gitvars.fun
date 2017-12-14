#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

# Functions: loadcrm_gitconfig checkcrm_gitconfig


loadadmin_gitconfig() {

ADMINVARSLIST=$(git config --global -l | grep -E '(github|xdruple)' | cut -d . -f 2-)

if [[ -z ${ADMINVARSLIST} ]]; then
echo "No gitconfig vars for Admin?"
else

for ADMINVAR in ${ADMINVARSLIST}; do
export ${ADMINVAR}
done

export GITHUB_TOKEN=$token
export UPDATEREADME=$updatereadme
export XDREPOPREFIX=$xdrepoprefix
export XDWORKDIR=$xdworkdir
export XDDREPOURL=$cddrepourl
export GITXDDIR=$gitxddir
fi

composer config --global github-oauth.github.com ${GITHUB_TOKEN}

}



loadcrm_gitconfig() {

if [[ -z ${CRMACCT} ]]; then
read -p "CRMACCT Needed: " CRMACCT
fi

PHPVARSLIST=$(git config --global -l | grep ${CRMACCT,,}env | cut -d . -f 2-)

if [[ -z ${PHPVARSLIST} ]]; then
echo "No gitconfig vars for ${CRMACCT}"
else

for PHPVAR in ${PHPVARSLIST}; do
export ${PHPVAR}
echo "export ${PHPVAR}"
done
echo "Found and exported vars for ${CRMACCT}"

fi
}

checkcrm_gitconfig() {

USEXDRUPLEAPIKEYS=0
WHICHSHIP="${CRMACCT,,}env"

git config --global -l | grep -E '(xdrupleshipping)' > /dev/null
RET=$?
if [[ ${RET} > 0 ]]; then
echo "You do not have xdrupleshipping keys"

else


if [[ ${CRMACCT} = "xTupleBuild" ]]; then
unset USEXDRUPLEAPIKEYS
USEXDRUPLEAPIKEYS=1
WHICHSHIP="xdrupleshipping"

else
echo "I found xTuple Shipping API Keys "
read -r -p "Do you want to them? [y,N] " response
response=${response,,}

if [[ "$response" =~ ^(yes|y)$ ]]; then
unset USEXDRUPLEAPIKEYS
USEXDRUPLEAPIKEYS=1
WHICHSHIP="xdrupleshipping"

fi

fi

fi


XDREPOPREFIX=$(git config --get xdruple.xdrepoprefix)
if [[ -z ${XDREPOPREFIX} ]]; then
XDREPOPREFIX=xd_
git config --global xdruple.xdrepoprefix "${XDREPOPREFIX}"
fi
    
#environment - should be ERP_ENVIRONMENT for consistency in this section
ENVIRONMENT=$(git config --get ${WHICHSHIP}.environment)
if [[ -z ${ENVIRONMENT} ]]; then
git config --global ${CRMACCT,,}env.environment "{ENVIRONMENT}"
fi

#application
ERP_APPLICATION=$(git config --get ${WHICHSHIP}.erpapplication)
if [[ -z ${ERP_APPLICATION} ]]; then
git config --global ${CRMACCT,,}env.erpapplication "{ERP_APPLICATION}"
fi

#host
ERP_HOST=$(git config --get ${WHICHSHIP}.erphost)
if [[ -z ${ERP_HOST} ]]; then
git config --global ${CRMACCT,,}env.erphost "{ERP_HOST}"
fi

#database
ERP_DATABASE=$(git config --get ${WHICHSHIP}.erpdatabase)
if [[ -z ${ERP_DATABASE} ]]; then
git config --global ${CRMACCT,,}env.erpdatabase "{ERP_DATABASE}"
fi

#iss
ERP_ISS=$(git config --get ${WHICHSHIP}.erpiss)
if [[ -z ${ERP_ISS} ]]; then
git config --global ${CRMACCT,,}env.erpiss "{ERP_ISS}"
fi

#key
ERP_KEY_FILE_PATH=$(git config --get ${WHICHSHIP}.erpkeyfilepath)
if [[ -z ${ERP_KEY_FILE_PATH} ]]; then
git config --global ${CRMACCT,,}env.erpkeyfilepath "{ERP_KEY_FILE_PATH}"
fi

#debug
ERP_DEBUG=$(git config --get ${WHICHSHIP}.erpdebug)
if [[ -z ${ERP_DEBUG} ]]; then
git config --global ${CRMACCT,,}env.erpdebug "{ERP_DEBUG}"
fi

COMMERCE_AUTHNET_AIM_LOGIN=$(git config --get ${WHICHSHIP}.commerceauthnetaimlogin)
if [[ -z ${COMMERCE_AUTHNET_AIM_LOGIN} ]]; then
git config --global ${CRMACCT,,}env.commerceauthnetaimlogin "YOUR_COMMERCE_AUTHNET_AIM_LOGIN"
fi

COMMERCE_AUTHNET_AIM_TRANSACTION_KEY=$(git config --get ${WHICHSHIP}.commerceauthnetaimtransactionkey)
if [[ -z ${COMMERCE_AUTHNET_AIM_TRANSACTION_KEY} ]]; then
git config --global ${CRMACCT,,}env.commerceauthnetaimtransactionkey "YOUR_COMMERCE_AUTHNET_AIM_TRANSACTION_KEY"
fi

UPS_ACCOUNT_ID=$(git config --get ${WHICHSHIP}.upsaccountid)
if [[ -z ${UPS_ACCOUNT_ID} ]]; then
git config --global ${CRMACCT,,}env.upsaccountid "YOUR_UPS_ACCOUNT_ID"
fi

UPS_ACCESS_KEY=$(git config --get ${WHICHSHIP}.upsaccesskey)
if [[ -z ${UPS_ACCESS_KEY} ]]; then
git config --global ${CRMACCT,,}env.upsaccesskey "YOUR_UPS_ACCESS_KEY"
fi

UPS_USER_ID=$(git config --get ${WHICHSHIP}.upsuserid)
if [[ -z ${UPS_USER_ID} ]]; then
git config --global ${CRMACCT,,}env.upsuserid "YOUR_UPS_USER_ID"
fi

UPS_PASSWORD=$(git config --get ${WHICHSHIP}.upspassword)
if [[ -z ${UPS_PASSWORD} ]]; then
git config --global ${CRMACCT,,}env.upspassword "YOUR_UPS_PASSWORD"
fi

UPS_PICKUP_SCHEDULE=$(git config --get ${WHICHSHIP}.upspickupschedule)
if [[ -z ${UPS_PICKUP_SCHEDULE} ]]; then
git config --global ${CRMACCT,,}env.upspickupschedule "DAILY_PICKUP"
fi

FEDEX_BETA=$(git config --get ${WHICHSHIP}.fedexbeta)
if [[ -z ${FEDEX_BETA} ]]; then
git config --global ${CRMACCT,,}env.fedexbeta "TRUE"
fi

FEDEX_KEY=$(git config --get ${WHICHSHIP}.fedexkey)
if [[ -z ${FEDEX_KEY} ]]; then
git config --global ${CRMACCT,,}env.fedexkey "YOUR_FEDEX_KEY"
fi

FEDEX_PASSWORD=$(git config --get ${WHICHSHIP}.fedexpassword)
if [[ -z ${FEDEX_PASSWORD} ]]; then
git config --global ${CRMACCT,,}env.fedexpassword "YOUR_FEDEX_PASSWORD"
fi

FEDEX_ACCOUNT_NUMBER=$(git config --get ${WHICHSHIP}.fedexaccountnumber)
if [[ -z ${FEDEX_ACCOUNT_NUMBER} ]]; then
git config --global ${CRMACCT,,}env.fedexaccountnumber "YOUR_FEDEX_ACCOUNT"
fi

FEDEX_METER_NUMBER=$(git config --get ${WHICHSHIP}.fedexmeternumber)
if [[ -z ${FEDEX_METER_NUMBER} ]]; then
git config --global ${CRMACCT,,}env.fedexmeternumber "YOUR_METER_NUMBER"
fi



}


