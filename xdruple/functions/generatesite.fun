#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

# Creates OAuth Token for xDruple
# Need to select a database connection for
# ERP_DBCONN
# This creates your keys, installs them.  This also sets up your PHP ENV.

source ${PWD}/gitvars.fun

CONF_TIME=$(date +'%s')


loadadmin_gitconfig


if [[ -e xdruplesettings.ini ]]; then

read -p "Do you want to use settings in xdruplesettings.ini? " -n 1 -r
echo    # (optional) move to a new line

  if [[ $REPLY =~ ^[Yy]$ ]]; then

echo "Using xdruplesettings.ini"
source xdruplesettings.ini
cat xdruplesettings.ini
read dummy

else
echo "Not Using xdruplesettings.ini"

fi
fi

if [[ -e shippingkeys.ini ]]; then

read -p "Do you want to use settings in shippingkeys.ini? " -n 1 -r
echo    # (optional) move to a new line
 if [[ $REPLY =~ ^[Yy]$ ]]; then

source shippingkeys.ini
echo "Using shippingkeys.ini"

else
echo "Not using shippingkeys.ini"
fi
fi

loadcrm_gitconfig
checkcrm_gitconfig
XDRUPLE_TEMPLATE=${XDREPOPREFIX}${CRMACCT,,}


#if [[ -z ${GITHUB_TOKEN} && -e oatokens.txt ]]; then
#	GITHUB_TOKEN=$(<oatokens.txt)
echo "Using Github Token ${GITHUB_TOKEN}"
#fi


generateOA()
{
# This value is in xdruplesettings.ini
#Having something other than "development", "stage"  or "production" here we might have an unexpected behavior
echo "What sort of environment are you configuring?"
read -p "Valid options are production or development. (default: production)" PHP_XDRUPLE_ENV
if [[ -z ${PHP_XDRUPLE_ENV} ]]; then
PHP_XDRUPLE_ENV="production"
fi

echo "Enter your Ecommerce Admin Email: (default: admin@${CRMACCT,,}.xd)"
read ECOMM_ADMIN_EMAIL
if [[ -z ${ECOMM_ADMIN_EMAIL} ]]; then
ECOMM_ADMIN_EMAIL="admin@${CRMACCT,,}.xd"
fi

echo "Enter your Ecommerce FQDN: (default: shop.${CRMACCT,,}.xd)"
read NGINX_ECOM_DOMAIN
if [[ -z ${NGINX_ECOM_DOMAIN} ]]; then
NGINX_ECOM_DOMAIN="shop.${CRMACCT,,}.xd"
ECOMM_SITE_URL="http://${NGINX_ECOM_DOMAIN}"
ERP_SITE_URL=https://${NGINX_SITE}/${DATABASE}
NGINX_SITE=http://erp.${CRMACCT,,}.xd
fi

echo "Enter your Ecommerce Site Name: (default: ${CRMACCT^} Demo Shop)"
read ECOMM_NAME
if [[ -z ${ECOMM_NAME} ]]; then
ECOMM_NAME="${CRMACCT^} Demo Shop"
fi

# Set up a unique dir to do our work.

WORK_TMP=${CRMACCT,,}_tokens_${CONF_TIME}

echo "WORK_TMP is: ${WORK_TMP}"

mkdir -p ${WORK_TMP}/{${PHP_XDRUPLE_ENV}_sql,${PHP_XDRUPLE_ENV}_keys,${PHP_XDRUPLE_ENV}_php}
KEYTMP=${WORK_TMP}/${PHP_XDRUPLE_ENV}_keys
SQLTMP=${WORK_TMP}/${PHP_XDRUPLE_ENV}_sql
PHPTMP=${WORK_TMP}/${PHP_XDRUPLE_ENV}_php


# THE P12 KEY OUT NEEDS TO GO IN /var/xtuple/keys/
KEY_P12_PATH=/var/xtuple/keys
sudo mkdir -p ${KEY_P12_PATH}

NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12

ssh-keygen -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}" -f ${KEYTMP}/keypair.key -P ''
openssl req -batch -new -key ${KEYTMP}/keypair.key -out ${KEYTMP}/keypair.csr
openssl x509 -req -in ${KEYTMP}/keypair.csr -signkey ${KEYTMP}/keypair.key -out ${KEYTMP}/keypair.crt
openssl pkcs12 -export -in ${KEYTMP}/keypair.crt -inkey ${KEYTMP}/keypair.key -out ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -password pass:notasecret
openssl pkcs12 -in ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -passin pass:notasecret -nocerts -nodes | openssl rsa > ${KEYTMP}/private.pem
openssl rsa -in ${KEYTMP}/private.pem -passin pass:notasecret -pubout -passout pass:notasecret > ${KEYTMP}/public.pem
sudo cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${KEY_P12_PATH}

OAPUBKEY=$(<${KEYTMP}/public.pem)
export OAPUBKEY=${OAPUBKEY}

}


setPG()
{

echo "What is your PostgreSQL Host? (default localhost): "
read PGHOST
if [[ -z ${PGHOST} ]]; then
PGHOST=localhost
fi

echo "What is your PostgreSQL Port? (default 5432): "
read PGPORT
if [[ -z ${PGPORT} ]]; then
PGPORT=5432
fi

echo "What is your xTupleERP Admin User? (default admin): "
read PGUSER
if [[ -z ${PGUSER} ]]; then
PGUSER=admin
fi

ERP_DBCONN_PRE="psql -Atq -U ${PGUSER} -h ${PGHOST} -p ${PGPORT}"
export ERP_DBCONN_PRE=${ERP_DBCONN_PRE}

echo "Using ${ERP_DBCONN_PRE}"
echo "Hit Any-key"
read dummy
}

selectdb()
{
echo "Select Database to Generate Oauth Token for: "

DATABASELIST=$(psql -At -h ${PGHOST} -p ${PGPORT} -U postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1') ORDER BY 1;") 

select DATABASE in ${DATABASELIST};
do
echo "You picked $DATABASE ($REPLY) "
break
done

ERP_DBCONN="psql -Atq -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -d ${DATABASE}"
export ERP_DBCONN=${ERP_DBCONN}
echo "Using Database: ${DATABASE}"
echo "Hit Any-key"
read dummy
}


generateoasql()
{

CLIENT_ID=$(${ERP_DBCONN} -c "INSERT INTO xt.oa2client(oa2client_client_id, oa2client_client_secret, oa2client_client_name, \
oa2client_client_email, oa2client_client_web_site, oa2client_client_type, oa2client_active, \
oa2client_issued, oa2client_delegated_access, oa2client_client_x509_pub_cert, oa2client_org) \
SELECT current_database()||'_'||xt.uuid_generate_v4() AS oa2client_client_id, xt.uuid_generate_v4() AS oa2client_client_secret, \
'${NGINX_ECOM_DOMAIN}' AS oa2client_client_name, '${ECOMM_ADMIN_EMAIL}' AS oa2client_client_email, \
'${ERP_SITE_URL}' AS oa2client_client_web_site, 'jwt bearer' AS oa2client_client_type, TRUE AS oa2client_active,  \
now() AS oa2client_issued , TRUE AS oa2client_delegated_access, '${OAPUBKEY}' AS oa2client_client_x509_pub_cert, current_database() AS  oa2client_org \
RETURNING oa2client_client_id; ")

export CLIENT_ID=${CLIENT_ID}

echo "The CLIENT_ID is ${CLIENT_ID}"

cat << EOF >> ${SQLTMP}/${DATABASE}_INSERT_xt.oa2client.sql
INSERT INTO xt.oa2client(oa2client_client_id, oa2client_client_secret, oa2client_client_name, \
oa2client_client_email, oa2client_client_web_site, oa2client_client_type, oa2client_active, \
oa2client_issued, oa2client_delegated_access, oa2client_client_x509_pub_cert, oa2client_org) \
SELECT current_database()||'_'||xt.uuid_generate_v4() AS oa2client_client_id, xt.uuid_generate_v4() AS oa2client_client_secret, \
'${NGINX_ECOM_DOMAIN}' AS oa2client_client_name, '${ECOMM_ADMIN_EMAIL}' AS oa2client_client_email, \
'${ERP_SITE_URL}' AS oa2client_client_web_site, 'jwt bearer' AS oa2client_client_type, TRUE AS oa2client_active,  \
now() AS oa2client_issued , TRUE AS oa2client_delegated_access, '${OAPUBKEY}' AS oa2client_client_x509_pub_cert, current_database() AS  oa2client_org \
RETURNING oa2client_client_id;
EOF

}

generatesitesql()
{
${ERP_DBCONN} -c "INSERT INTO xdruple.xd_site(xd_site_name, xd_site_url, xd_site_notes) SELECT '${DATABASE}_ecommerce','${ECOMM_SITE_URL}','ecomm site';"

cat << EOF >> ${SQLTMP}/${DATABASE}_INSERT_xdruple.xd_site.sql
INSERT INTO xdruple.xd_site(xd_site_name, xd_site_url, xd_site_notes) SELECT '${DATABASE}_ecommerce','${ECOMM_SITE_URL}','ecomm site';
EOF


}

generateEnvPHP()
{

# Environment - live, dev, stage - corresponds to /var/www/live|dev|stage, but I suppose it could be whatever you want the
# document root to be. This is used in NGINX confs for root directive, and is where we are cloning the drupal code into.
# i.e. git clone "https://yourgithubtoken:x-oauth-basic@github.com/xtuple/prodiem.git" /var/www/live

# This becomes the webroot
ENVIRONMENT=${PHP_XDRUPLE_ENV}_${NGINX_ECOM_DOMAIN}_${DATABASE}
export ENVIRONMENT=${PHP_XDRUPLE_ENV}_${NGINX_ECOM_DOMAIN}_${DATABASE}

if [[ -n ${XDRUPLE_TEMPLATE} ]]; then
echo "Using template ${XDRUPLE_TEMPLATE}"
export XDRUPLE_TEMPLATE=${XDRUPLE_TEMPLATE}

else
XDRUPLE_TEMPLATE=prodiem
echo "Using template ${XDRUPLE_TEMPLATE}"
export XDRUPLE_TEMPLATE=${XDRUPLE_TEMPLATE}

fi

read -p "Do you want to download the Drupal Template ${XDRUPLE_TEMPLATE}? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]; then

if [[  -d /var/www/${ENVIRONMENT} ]]; then
echo "/var/www/${ENVIRONMENT} already exists"
else
 sudo git clone "https://${GITHUB_TOKEN}:x-oauth-basic@github.com/xtuple/${XDRUPLE_TEMPLATE}" /var/www/${ENVIRONMENT}
fi

fi

#xTuple REST API
RESCUED_APP_NAME=$(${ERP_DBCONN} -c "SELECT oa2client_client_name FROM xt.oa2client WHERE oa2client_client_id = '${CLIENT_ID}';")
echo "RESCUED_APP_NAME::  ${RESCUED_APP_NAME}"


if [[ -z ${RESCUED_APP_NAME} ]]; then
RESCUED_APP_NAMES=$(${ERP_DBCONN} -c "SELECT oa2client_client_name FROM xt.oa2client;")
echo "We didn't get an app name..."
select RESCUED_APP_NAME in ${RESCUED_APP_NAMES};
do
echo "You picked $RESCUED_APP_NAME ($REPLY) "
break
done
fi


RESCUED_URL=$(${ERP_DBCONN} -c "SELECT oa2client_client_web_site FROM xt.oa2client WHERE oa2client_client_id = '${CLIENT_ID}';")

if [[ -z ${RESCUSED_URL} ]]; then
RESCUED_URLS=$(${ERP_DBCONN} -c "SELECT oa2client_client_web_site FROM xt.oa2client;")
select RESCUED_URL in ${RESCUED_URLS};
do
echo "You picked $RESCUED_URL ($REPLY) "
break
done
fi

RESCUED_ISS=${CLIENT_ID}
if [[ -z ${RESCUSED_ISS} ]]; then
RESCUED_ISSS=$(${ERP_DBCONN} -c "SELECT oa2client_client_id FROM xt.oa2client;")
select RESCUED_ISS in ${RESCUED_ISSS};
do
echo "You picked $RESCUED_ISS ($REPLY) "
break
done
fi


RESCUED_KEY_FILE=/var/xtuple/keys/${RESCUED_APP_NAME}.p12
if [[ -e ${RESCUED_KEY_FILE} ]]; then
echo "Key File - ${RESCUED_KEY_FILE} - is Empty"
fi

# Can set to FALSE, Should ask...
RESCUED_DEBUG=TRUE

# THIS OUTPUT GETS PUT IN /var/www/{ENVIRONMENT}/config/environment.php
# Shipping methods must match what is in xtuple. Need to work on this.
cat << EOF > ${PHPTMP}/environment.php
<?php

\$configuration = [
  'environment' => '${PHP_XDRUPLE_ENV}',
  'xtuple_rest_api' => [
    'app_name' => '${RESCUED_APP_NAME}',
    'url' => '${RESCUED_URL}',
    'database' => '${DATABASE}',
    'iss' => '${RESCUED_ISS}',
    'key' => '${RESCUED_KEY_FILE}',
    'debug' => ${RESCUED_DEBUG}
  ],
  'authorize_net' => [
    'login' => '${COMMERCE_AUTHNET_AIM_LOGIN}',
    'tran_key' => '${COMMERCE_AUTHNET_AIM_TRANSACTION_KEY}',
  ],
  'ups' => [
    'accountId' => '${UPS_ACCOUNT_ID}',
    'accessKey' => '${UPS_ACCESS_KEY}',
    'userId' => '${UPS_USER_ID}',
    'password' => '${UPS_PASSWORD}',
    'pickupSchedule' => '${UPS_PICKUP_SCHEDULE}',
  ],
  'fedex' => [
    'beta' => ${FEDEX_BETA},
    'key' => '${FEDEX_KEY}',
    'password' => '${FEDEX_PASSWORD}',
    'accountNumber' => '${FEDEX_ACCOUNT_NUMBER}',
    'meterNumber' => '${FEDEX_METER_NUMBER}',
  ],
  'xdruple_shipping' => [
    'specialty' => [
      'specialty' => [
        'code' => 'SPECIALTY',
        'freightClasses' => [
          'BULK',
        ],
        'alwaysAllow' => TRUE,
        'allowedServices' => [
          'customer_pickup',
        ],
      ],
    ],
    'delivery' => [
      'local_delivery' => [
        'code' => 'DELIVERY-LOCAL',
        'rate' => 1499,
      ],
    ],
    'fedex' => [
      'fedex_ground' => [
        'code' => 'FEDEX - Ground',
      ],
    ],
    'ups' => [
      'ups_ground' => [
        'code' => 'UPS-GROUND',
      ],
    ],
    'pickup' => [
      'customer_pickup' => [
        'code' => 'CUSTOMER-PICKUP',
      ],
    ],
  ],
];

EOF
echo "Created ${PHPTMP}/environment.php"

echo "Created /var/www/${ENVIRONMENT}/config/environment.php"

ENV_ALT="environment.php-${CONF_TIME}"

if [[ -e  /var/www/${ENVIRONMENT}/config/environment.php ]]; then

echo "environment.php already exists, copying it as /var/www/${ENVIRONMENT}/config/environment.php-${CONF_TIME}"
 sudo cp ${PHPTMP}/environment.php /var/www/${ENVIRONMENT}/config/${ENV_ALT}

else

echo "copying environment.php to /var/www/${ENVIRONMENT}/config/environment.php"
sudo cp ${PHPTMP}/environment.php /var/www/${ENVIRONMENT}/config/environment.php

fi

}


setPG
selectdb
generateOA
generateoasql
generatesitesql
# applyScripts
generateEnvPHP

exit 0;
