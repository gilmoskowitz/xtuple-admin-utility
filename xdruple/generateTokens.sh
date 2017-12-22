#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

# Creates OAuth Token for xDruple
# Need to select a database connection for
# ERP_DBCONN
# This creates your keys, installs them.  This also sets up your PHP ENV.

DEPLOYER_NAME=$(whoami)

source functions/gitvars.fun

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

echo "Using Github Token ${GITHUB_TOKEN}"

generateOA()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
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

  echo "Enter your Ecommerce FQDN: (default: shop.${CRMACCT,,}.xd) "
  read NGINX_ECOM_DOMAIN
  if [[ -z ${NGINX_ECOM_DOMAIN} ]]; then
    NGINX_ECOM_DOMAIN="shop.${CRMACCT,,}.xd"
  fi

  ECOMM_SITE_URL="http://${NGINX_ECOM_DOMAIN}"

  echo "Enter your ERP FQDN: (default: shop.${CRMACCT,,}.xd) "
  echo "Do NOT enter the protocol. "
  read NGINX_SITE
  # if [[ -z ${NGINX_SITE} ]]; then
  # THIS MUST BE HTTPS IN THE ENVPHP!
  NGINX_SITE=https://${NGINX_SITE}
  NGINX_SITE_NOPROTOCOL=${NGINX_SITE}
  ERP_SITE_URL=${NGINX_SITE}/${DATABASE}
  #fi

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

  MONGO_ADMIN_USER=admin
  MONGO_ADMIN_PASS=admin
  ECOMM_DB_NAME=xd_${DATABASE}
  ECOMM_DB_USER=xd_admin
  ECOMM_DB_PASS=xd_admin
  ECOMM_XD_USER_PASS=developer
  #ECOMM_ADMIN_EMAIL=admin@${CRMACCT,,}.xd
  #ECOMM_SITE_URL=http://shop.${CRMACCT,,}.xd
  #ERP_SITE_URL=https://${NGINX_SITE}/${DATABASE}

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

create_mongo_db_auto() {
  sudo mongo admin --eval='db.dropUser("admin")'
  sudo mongo admin --eval='db.createUser({ user: "admin", pwd: "'${MONGO_ADMIN_PASS}'", roles: [{ role: "userAdminAnyDatabase", db: "admin" }] })'

  sudo mongo admin --eval='db.dropUser("${ECOMM_DB_USER}")'
  sudo mongo ${ECOMM_DB_NAME} --eval='db.dropDatabase()'
  sudo mongo admin --eval='db.getSiblingDB("'${ECOMM_DB_NAME}'").createUser({ user: "'${ECOMM_DB_USER}'", pwd: "'${ECOMM_DB_PASS}'", roles: [ "dbOwner"] })'
}

setPG()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

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

selectdb() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  echo "Select Database to Generate Oauth Token for: "

  DATABASELIST=$(psql -At -h ${PGHOST} -p ${PGPORT} -U postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres','template0','template1') ORDER BY 1;") 

  select DATABASE in ${DATABASELIST}; do
    echo "You picked $DATABASE ($REPLY) "
    break
  done

  ERP_DBCONN="psql -Atq -U ${PGUSER} -h ${PGHOST} -p ${PGPORT} -d ${DATABASE}"
  export ERP_DBCONN=${ERP_DBCONN}
  echo "Using Database: ${DATABASE}"
  echo "Hit Any-key"
  read dummy
}

generateoasql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local INSERTSTR="INSERT INTO xt.oa2client(
                            oa2client_client_id, oa2client_client_secret,
                            oa2client_client_name, oa2client_client_email,
                            oa2client_client_web_site, oa2client_client_type, oa2client_active,
                            oa2client_issued, oa2client_delegated_access,
                            oa2client_client_x509_pub_cert, oa2client_org
                   ) SELECT current_database()||'_'||xt.uuid_generate_v4() AS oa2client_client_id, xt.uuid_generate_v4() AS oa2client_client_secret,
                            '${NGINX_ECOM_DOMAIN}' AS oa2client_client_name, '${ECOMM_ADMIN_EMAIL}' AS oa2client_client_email,
                            '${ERP_SITE_URL}' AS oa2client_client_web_site, 'jwt bearer' AS oa2client_client_type, TRUE AS oa2client_active,
                            now() AS oa2client_issued, TRUE AS oa2client_delegated_access,
                            '${OAPUBKEY}' AS oa2client_client_x509_pub_cert, current_database() AS  oa2client_org
                   RETURNING oa2client_client_id;"

  export CLIENT_ID=$(${ERP_DBCONN} -c "$INSERTCMD")
  echo "The CLIENT_ID is ${CLIENT_ID}"

  echo $INSERTSTR >> ${SQLTMP}/${DATABASE}_INSERT_xt.oa2client.sql
}

generatesitesql()
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local INSERTSTR="INSERT INTO xdruple.xd_site(xd_site_name, xd_site_url, xd_site_notes) SELECT '${DATABASE}_ecommerce','${ECOMM_SITE_URL}','ecomm site';"

  ${ERP_DBCONN} -c "$INSERTSTR"
  echo $INSERTSTR >> ${SQLTMP}/${DATABASE}_INSERT_xdruple.xd_site.sql
}

setEnvPHP() {
  # This becomes the webroot
  export ENVIRONMENT=${PHP_XDRUPLE_ENV}_${NGINX_ECOM_DOMAIN}_${DATABASE}
  export XDENV_ROOT=/var/www/${ENVIRONMENT}
}

generateEnvPHP() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  # Environment - live, dev, stage - corresponds to /var/www/live|dev|stage, but I suppose it could be whatever you want the
  # document root to be. This is used in NGINX confs for root directive, and is where we are cloning the drupal code into.
  # i.e. git clone "https://yourgithubtoken:x-oauth-basic@github.com/xtuple/prodiem.git" /var/www/live

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

  #xTuple REST API; app_name in environment.php must match xd_site_name
  RESCUED_APP_NAME=$(${ERP_DBCONN} -c "SELECT oa2client_client_name FROM xt.oa2client WHERE oa2client_client_id = '${CLIENT_ID}';")
  if [[ -z ${RESCUED_APP_NAME} ]]; then
    RESCUED_APP_NAMES=$(${ERP_DBCONN} -c "SELECT oa2client_client_name FROM xt.oa2client;")
    echo "We didn't get an app name..."
    select RESCUED_APP_NAME in ${RESCUED_APP_NAMES}; do
      break
    done
  fi
  ${ERP_DBCONN} -c "UPDATE xdruple.xd_site SET xd_site_name='${RESCUED_APP_NAME}' WHERE xd_site_name='${DATABASE}_ecommerce' AND xd_site_url='${ECOMM_SITE_URL}';"
  echo "RESCUED_APP_NAME::  ${RESCUED_APP_NAME}"

  RESCUED_URL=$(${ERP_DBCONN} -c "SELECT oa2client_client_web_site FROM xt.oa2client WHERE oa2client_client_id = '${CLIENT_ID}';")
  if [[ -z ${RESCUED_URL} ]]; then
    RESCUED_URLS=$(${ERP_DBCONN} -c "SELECT oa2client_client_web_site FROM xt.oa2client;")
    echo "We couldn't find a URL..."
    select RESCUED_URL in ${RESCUED_URLS}; do
      echo "You picked $RESCUED_URL ($REPLY) "
      break
    done
  fi

  RESCUED_ISS=${CLIENT_ID}
  if [[ -z ${RESCUED_ISS} ]]; then
    RESCUED_ISSS=$(${ERP_DBCONN} -c "SELECT oa2client_client_id FROM xt.oa2client;")
    select RESCUED_ISS in ${RESCUED_ISSS}; do
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
      'url' => '${NGINX_SITE}',
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
    'xdruple_shipping' => [],
  ];
EOF
  echo "Created ${PHPTMP}/environment.php"

  ENV_ALT="environment.php-${CONF_TIME}"

  if [[ -e /var/www/${ENVIRONMENT}/config/environment.php ]]; then
    echo "environment.php already exists, copying it as /var/www/${ENVIRONMENT}/config/environment.php-${CONF_TIME}"
    sudo cp ${PHPTMP}/environment.php /var/www/${ENVIRONMENT}/config/${ENV_ALT}
  else
    echo "copying environment.php to /var/www/${ENVIRONMENT}/config/environment.php"
    sudo cp ${PHPTMP}/environment.php /var/www/${ENVIRONMENT}/config/environment.php
    echo "Created /var/www/${ENVIRONMENT}/config/environment.php"
  fi
}

composerRun() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  sudo su - ${DEPLOYER_NAME} -c "composer config --global process-timeout 600"
  sudo su - ${DEPLOYER_NAME} -c "composer config --global preferred-install source"
  sudo su - ${DEPLOYER_NAME} -c "composer config --global secure-http false"
  sudo su - ${DEPLOYER_NAME} -c "composer config --global github-protocols https git ssh"

  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${XDENV_ROOT}

  sudo su - ${DEPLOYER_NAME} -c "cd ${XDENV_ROOT} && composer install"
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "composer install failed for some reason."
    exit 0
  fi

  sudo su - ${DEPLOYER_NAME} -c "cd ${XDENV_ROOT} && sudo ./console.php install:prepare:directories"
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "console.php install:prepare:directories failed for some reason."
    exit 0
  fi

  sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} ${XDENV_ROOT}
  # This script drops db if exists... and the role/user... needs to change.
  # sleep 10
  pushd ${XDENV_ROOT}
  echo "${ECOMM_DB_NAME} ${ECOMM_DB_PASS} ${ECOMM_DB_USER}"

  cat << EOF >> console.log
./console.php install:drupal --db-name=${ECOMM_DB_NAME} --db-pass=${ECOMM_DB_PASS} --db-user=${ECOMM_DB_USER} --user-pass=${ECOMM_XD_USER_PASS} --site-mail=${ECOMM_ADMIN_EMAIL}  --site-name="${ECOMM_NAME}"
EOF

  ./console.php install:drupal --db-name=${ECOMM_DB_NAME} --db-pass=${ECOMM_DB_PASS} --db-user=${ECOMM_DB_USER} --user-pass=${ECOMM_XD_USER_PASS} --site-mail=${ECOMM_ADMIN_EMAIL}  --site-name="${ECOMM_NAME}"
  RET=$?
  if [ $RET -ne 0 ]; then
    echo "Failed: ./console.php install:drupal --mongo-admin-user=${MONGO_ADMIN_USER} --mongo-admin-pass=${MONGO_ADMIN_PASS} --db-name=${ECOMM_DB_NAME} --db-pass=${ECOMM_DB_PASS} --db-user=${ECOMM_DB_USER} --user-pass=${ECOMM_XD_USER_PASS} --site-mail=${ECOMM_ADMIN_EMAIL}  --site-name=${ECOMM_NAME}" >> ConsoleCommand-out.log
    popd
    exit 0
  fi
  popd

  sudo chown -R www-data:www-data ${XDENV_ROOT}/web
}

webrootnote() {
  if type "ec2metadata" > /dev/null; then
    #prefer this if we have it and we're on EC2...
    IP=$(ec2metadata --public-ipv4)
  else
    IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
  fi

  if [[ -z ${IP} ]]; then
    IP="The IP of This Machine"
  fi

  cat << EOF >> ${DATABASE}_connection.log
       ************************************"
       ***** IMPORTANT!!! PLEASE READ *****"
       ************************************"
   
       Here is the information to get logged in!
   
       First, Add the following to your system's hosts file
       Windows: %SystemRoot%\System32\drivers\etc\hosts
       OSX/Linux: /etc/hosts
       ${IP} ${NGINX_ECOM_DOMAIN} ${NGINX_SITE_NOPROTOCOL}
   
       xTuple Desktop Client Login:
       Server: ${IP}
       Port: ${PGPORT}
       Database: ${DATABASE}
       User: admin
       Pass: admin
   
       xTuple Mobile Web Client Login:
       Login at ${NGINX_SITE}
       User: admin
       Pass: admin
   
       Ecommerce Site Login:
       Login at ${NGINX_ECOM_DOMAIN}/login
       User: Developer
       Pass: ${ECOMM_XD_USER_PASS}

       Nginx Config: 
       Webroot: /var/www/${ENVIRONMENT}
   
    Please set your nginx config for the xTupleCommerce webroot to:
    root ${XDENV_ROOT}/drupal/core;
EOF
  cat ${DATABASE}_connection.log
}

gatherVars() {
# for i in _ {a..z} {A..Z}; do
#    for var in $(eval echo "\\${!$i@}"); do
#      echo $var
#      # you can test if $var matches some criteria and put it in the file or ignore
#   done 
#done
  declare -p >> variables.log
}

setPG
selectdb
generateOA
generateoasql
generatesitesql
## applyScripts
# create_mongo_db_auto
setEnvPHP
generateEnvPHP

echo "We're ready to set this up. Hit any key."
read dummy
composerRun
webrootnote
gatherVars

exit 0
