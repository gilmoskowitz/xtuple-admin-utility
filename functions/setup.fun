#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

export WORKDIR=$(pwd)
export DEPLOYER_NAME=$(whoami)

WORKDAY=$(date "+%m%d%y")
WORKDATE=$(date "+%m%d%y-%s")

read_configs() {
  if [[ -f ${WORKDIR}/CreatePackages-${WORKDAY}.config ]]; then
    source ${WORKDIR}/CreatePackages-${WORKDAY}.config
  fi

 if [[ ${NODE_ENV} ]]; then
   rm ${WORKDIR}/setup.bak
   ( echo  "NODE_ENV=${NODE_ENV}" ) | tee -a ${WORKDIR}/setup.bak
 fi

 if [[ ${PGVER} ]]; then
   ( echo  "PGVER=${PGVER}" ) | tee -a ${WORKDIR}/setup.bak
 fi

 if [[ ${MWC_VERSION} ]]; then
   ( echo "MWC_VERSION=${MWC_VERSION}" ) | tee -a ${WORKDIR}/setup.bak
 fi

 if [[ ${ERP_MWC_TARBALL} ]]; then
   ( echo "ERP_MWC_TARBALL=${ERP_MWC_TARBALL}" ) | tee -a ${WORKDIR}/setup.bak
 fi

 if [[ ${XTC_WWW_TARBALL} ]]; then
   ( echo "XTC_WWW_TARBALL=${XTC_WWW_TARBALL}" ) | tee -a ${WORKDIR}/setup.bak
 fi

  if [[ -f ${WORKDIR}/setup.ini ]]; then
    source ${WORKDIR}/setup.ini
  else
    echo "Missing setup.ini file."
    echo "We'll create a sample for you. Please review."

    ( echo "
export TIMEZONE=America/New_York
PGVER=9.5
MWC_VERSION=v4.11.1
ERP_DATABASE_NAME=xtupleerp
ERP_DATABASE_BACKUP=manufacturing_demo-4.11.0.backup
ERP_MWC_TARBALL=xTupleREST-v4.11.1.tar.gz
XTC_DATABASE_NAME=xtuplecommerce
XTC_DATABASE_BACKUP=xTupleCommerce-v4.11.1.backup
XTC_WWW_TARBALL=xTupleCommerce-v4.11.1.tar.gz
# payment-gateway config
# See https://github.com/bendiy/payment-gateways/tree/initial/gateways
GATEWAY_NAME='Example'
GATEWAY_HOSTNAME='api.example.com'
GATEWAY_BASE_PATH='/v1'
GATEWAY_NODE_LIB_NAME='example' " ) | tee -a ${WORKDIR}/setup.ini
    exit 2
  fi
}

read_xtau_configs() {
  if [[ -f ${WORKDIR}/xtau_mwc-${WORKDAY}.config ]]; then
    source ${WORKDIR}/xtau_mwc-${WORKDAY}.config
  fi

  if [[ ${NODE_ENV} ]]; then
    rm ${WORKDIR}/setup.bak
    ( echo  "NODE_ENV=${NODE_ENV}" ) | tee -a ${WORKDIR}/setup.bak
  fi

  if [[ ${PGVER} ]]; then
    ( echo  "PGVER=${PGVER}" ) | tee -a ${WORKDIR}/setup.bak
  fi

  if [[ ${MWC_VERSION} ]]; then
    ( echo "MWC_VERSION=${MWC_VERSION}" ) | tee -a ${WORKDIR}/setup.bak
  fi

  if [[ ${ERP_MWC_TARBALL} ]]; then
    ( echo "ERP_MWC_TARBALL=${ERP_MWC_TARBALL}" ) | tee -a ${WORKDIR}/setup.bak
  fi

  if [[ -f ${WORKDIR}/setup.ini ]]; then
    source ${WORKDIR}/setup.ini
  else
    echo "Missing setup.ini file."
    echo "We'll create a sample for you. Please review."

    ( echo "
export TIMEZONE=America/New_York
PGVER=9.6
MWC_VERSION=v4.11.1
ERP_DATABASE_NAME=xtupleerp
ERP_DATABASE_BACKUP=manufacturing_demo-4.11.0.backup
ERP_MWC_TARBALL=xTupleREST-v4.11.1.tar.gz
XTC_DATABASE_NAME=xtuplecommerce
XTC_DATABASE_BACKUP=xTupleCommerce-v4.11.1.backup
XTC_WWW_TARBALL=xTupleCommerce-v4.11.1.tar.gz
# payment-gateway config
# See https://github.com/bendiy/payment-gateways/tree/initial/gateways
GATEWAY_NAME='Example'
GATEWAY_HOSTNAME='api.example.com'
GATEWAY_BASE_PATH='/v1'
GATEWAY_NODE_LIB_NAME='example' " ) | tee -a ${WORKDIR}/setup.ini

    exit 2
  fi
}

setup_sudo() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if [[ ! -f /etc/sudoers.d/90-xtau-users ]] || ! grep -q "${DEPLOYER_NAME}" /etc/sudoers.d/90-xtau-users; then
    echo "Setting up user: $DEPLOYER_NAME for sudo"
    echo "You might be prompted for your password."
    (echo '
# User rules for xtau

'${DEPLOYER_NAME}' ALL=(ALL) NOPASSWD:ALL'
    )| sudo tee -a /etc/sudoers.d/90-xtau-users >/dev/null

  else
    echo "User: $DEPLOYER_NAME already setup in sudoers.d"
  fi
}

initial_update() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  sudo apt-get update
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "apt-get returned $RET trying to update"
    echo "Log out and back in and try again"
    exit 2
  fi
}

add_mwc_user() {
  sudo useradd xtuple -m -s /bin/bash
}

check_pgdep() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if type -p "pg_config" > /dev/null; then
    echo "pg_config found. Good!"
  else
    echo "pg_config not found, please install postgresql-devel package."
    echo "building node_modules will fail."
    echo "Exiting."
    exit 0
  fi
}


install_npm_node() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cd $WORKDIR

  if type -p "n" > /dev/null; then
    echo "Found n"
  else
    echo "Need to install npm dependencies"

    wget https://raw.githubusercontent.com/visionmedia/n/master/bin/n -qO n
    chmod +x n
    sudo mv n /usr/bin/n
    sudo n 0.10.40
  fi

  if type -p "npm" > /dev/null; then
    echo "Found npm, checking version"
    NPM_VER=$(npm -v | grep -q '^2')

    if [[ -z $NPM_VER ]]; then
      echo "Need to upgrade npm to 2.x.x"
      sudo npm install -g npm@2.x.x
      RET=$?
      if [[ $RET -ne 0 ]]; then
	echo "Something happened installing npm@2.xx"
      else
	echo "npm upgraded successfully."
      fi
    else
     echo "Installed npm version ok."
   fi
  fi

  if type -p "browserify" > /dev/null; then
    echo "Found browserify"
  else
    echo "Need to install browserify dependencies globally"
    sudo npm install -g browserify
    RET=$?
    if [[ $RET -ne 0 ]]; then
      echo "Issue installing browserify"
    fi
  fi
}

check_npm() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cd $WORKDIR

  if type -p "npm" > /dev/null; then
    echo "Found npm, checking version"
    NPM_VER=$(npm -v | grep -q '^2')

    if [[ -z $NPM_VER ]]; then
      echo "Need to upgrade npm to 2.x.x"
      sudo npm install -g npm@2.x.x
      RET=$?
      if [[ $RET -ne 0 ]]; then
	echo "Something happened installing npm@2.xx"
      else
	echo "npm upgraded successfully."
      fi
    else
      echo "Installed npm version ok."
    fi
  fi
}

install_postgresql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if [[ -z ${PGVER} ]]; then
    echo "Need to set PGVER before running"
    echo "i.e.: export PGVER=9.6"
    exit 0
  fi

# check to make sure the PostgreSQL repo is already added on the system
  if [ ! -f /etc/apt/sources.list.d/pgdg.list ] || ! grep -q "apt.postgresql.org" /etc/apt/sources.list.d/pgdg.list; then
    sudo bash -c "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -"
    sudo bash -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  fi

# We handle this package separately - if create_main_cluster is true, then it can cause issues for our purposes.
  sudo apt-get -y install postgresql-common
  sudo sed -i -e s/'#create_main_cluster = true'/'create_main_cluster = false'/g /etc/postgresql-common/createcluster.conf

  POSTGRESQL_PACKAGES="postgresql-${PGVER} postgresql-client-${PGVER} postgresql-contrib-${PGVER} postgresql-server-dev-${PGVER} postgresql-client-${PGVER} postgresql-${PGVER}-plv8"

  for POSTGRESQL_PACKAGE in $POSTGRESQL_PACKAGES; do
    dpkg-query -Wf'${Status}' $POSTGRESQL_PACKAGE 2>/dev/null | grep -q "install ok installed";
    RET=$?
    if [[ $RET == 0 ]]; then
      echo "$POSTGRESQL_PACKAGE Is Installed"
    else
      echo "Installing ${POSTGRESQL_PACKAGE}"
      sudo apt-get -y install $POSTGRESQL_PACKAGE
      RET=$?
      if [[ $RET != 0 ]]; then
        echo "apt-get returned $RET trying to install $POSTGRESQL_PACKAGE"
        exit 2
      fi
    fi
  done
}

setup_postgresql_cluster() {
  CLUSTERINFO=$(pg_lsclusters -h)

  echo "$CLUSTERINFO" | grep -q "5432"
  RET=$?

  if [[ $RET == 0 ]]; then
    echo "Already have a cluster on 5432"
    echo "$CLUSTERINFO"

  else
    echo "Creating PostgreSQL Cluster on 5432"

    sudo bash -c "su - root -c \"pg_createcluster --locale en_US.UTF8 -p 5432 ${PGVER} xtuple -o listen_addresses='*' -o log_line_prefix='%t %d %u ' -- --auth=trust --auth-host=trust --auth-local=trust\""
    sudo bash -c "echo  \"hostnossl  all           all             0.0.0.0/0                 reject\" >> /etc/postgresql/${PGVER}/xtuple/pg_hba.conf"
    sudo bash -c "echo  \"hostssl    all           postgres        0.0.0.0/0                 reject\" >> /etc/postgresql/${PGVER}/xtuple/pg_hba.conf"
    sudo bash -c "echo  \"hostssl    all           +xtrole         0.0.0.0/0                 md5\"    >> /etc/postgresql/${PGVER}/xtuple/pg_hba.conf"

    # We keep plv8 turned off until we restore the database.  This is becuase of a current issue with plv8.
    sudo bash -c "echo  \"#plv8.start_proc='xt.js_init'\" >> /etc/postgresql/${PGVER}/xtuple/postgresql.conf"

    sudo pg_ctlcluster ${PGVER} xtuple stop --force
    sudo pg_ctlcluster ${PGVER} xtuple start

    ALLCLUSTERS=$(pg_lsclusters)
    echo "Completed - these are your PostgreSQL clusters:"
    echo "${ALLCLUSTERS}"
  fi
}

generate_p12() {
  # THE P12 KEY OUT NEEDS TO GO IN /var/xtuple/keys/
  NGINX_ECOM_DOMAIN='xTupleCommerce'
  ECOMM_ADMIN_EMAIL="admin@xtuple.xd"
  ERP_SITE_URL='xtuple.xd'

  KEY_P12_PATH=${WORKDIR}/private
  KEYTMP=${KEY_P12_PATH}/tmp
  mkdir -p ${KEY_P12_PATH}
  mkdir -p ${KEYTMP}

  NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12

  ssh-keygen -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}" -f ${KEYTMP}/keypair.key -P ''
  openssl req -batch -new -key ${KEYTMP}/keypair.key -out ${KEYTMP}/keypair.csr
  openssl x509 -req -in ${KEYTMP}/keypair.csr -signkey ${KEYTMP}/keypair.key -out ${KEYTMP}/keypair.crt
  openssl pkcs12 -export -in ${KEYTMP}/keypair.crt -inkey ${KEYTMP}/keypair.key -out ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -password pass:notasecret
  openssl pkcs12 -in ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -passin pass:notasecret -nocerts -nodes | openssl rsa > ${KEYTMP}/private.pem
  openssl rsa -in ${KEYTMP}/private.pem -passin pass:notasecret -pubout -passout pass:notasecret > ${KEYTMP}/public.pem
  cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${KEY_P12_PATH}

  OAPUBKEY=$(<${KEYTMP}/public.pem)
  export OAPUBKEY=${OAPUBKEY}
  echo "Created OAPUBKEY"
}

generateoasql() {
  cat << EOF >> ${WORKDIR}/sql/oa2client.sql
  INSERT INTO xt.oa2client(oa2client_client_id, oa2client_client_secret, oa2client_client_name, \
  oa2client_client_email, oa2client_client_web_site, oa2client_client_type, oa2client_active, \
  oa2client_issued, oa2client_delegated_access, oa2client_client_x509_pub_cert, oa2client_org) \
  SELECT 'xTupleCommerceSite' AS oa2client_client_id, xt.uuid_generate_v4() AS oa2client_client_secret, \
  '${NGINX_ECOM_DOMAIN}' AS oa2client_client_name, '${ECOMM_ADMIN_EMAIL}' AS oa2client_client_email, \
  '${ERP_SITE_URL}' AS oa2client_client_web_site, 'jwt bearer' AS oa2client_client_type, TRUE AS oa2client_active,  \
  now() AS oa2client_issued , TRUE AS oa2client_delegated_access, '${OAPUBKEY}' AS oa2client_client_x509_pub_cert, current_database()
  AS  oa2client_org
  WHERE NOT EXISTS ( SELECT 1 FROM xt.oa2client WHERE oa2client_client_x509_pub_cert='${OAPUBKEY}');
EOF
}

#Turn on plv8 and restart postgresql.
turn_on_plv8() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local POSTGRESQL_CONF=/etc/postgresql/${PGVER}/xtuple/postgresql.conf

  sudo sed -i '/^#plv8.start_proc/c\plv8.start_proc='\'xt.js_init\''' ${POSTGRESQL_CONF}
  sudo pg_ctlcluster ${PGVER} xtuple stop --force
  sudo pg_ctlcluster ${PGVER} xtuple start
}

#Turn off plv8 and restart postgresql.
turn_off_plv8() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local POSTGRESQL_CONF=/etc/postgresql/${PGVER}/xtuple/postgresql.conf

  sudo sed -i '/^plv8.start_proc/c\#plv8.start_proc='\'xt.js_init\''' ${POSTGRESQL_CONF}
  sudo pg_ctlcluster ${PGVER} xtuple stop --force
  sudo pg_ctlcluster ${PGVER} xtuple start
}

setup_erp_db() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  psql -U postgres -c "CREATE ROLE xtrole;" 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "Warning or Fail on: CREATE ROLE xtrole. Already exists?"
  fi

  psql -U postgres -c "CREATE USER admin SUPERUSER PASSWORD 'admin' IN GROUP xtrole;" 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "Warning or Fail on: CREATE USER admin. Already exists?"
  fi

  psql -At -U postgres -l | grep -q ${ERP_DATABASE_NAME} 2>/dev/null
  RET=$?
  if [[ $RET == 0 ]]; then
     echo "Database ${ERP_DATABASE_NAME} already exists"
  else
    echo "Creating ${ERP_DATABASE_NAME}!"
    createdb -U admin -p 5432 ${ERP_DATABASE_NAME}
    psql -U admin ${ERP_DATABASE_NAME} -c "CREATE EXTENSION plv8;"

    if [[ ! -f ${WORKDIR}/db/${ERP_DATABASE_BACKUP} ]]; then
      echo "File not found! ${WORKDIR}/db/${ERP_DATABASE_BACKUP}"
      echo "Don't know what you want me to restore!"
    else
      turn_off_plv8

      # Let's stop this service if running.
      echo "Stopping any node.js for this instance"
      sudo service xtuple-xtupleerp stop

      pg_restore -U admin -d ${ERP_DATABASE_NAME} ${WORKDIR}/db/${ERP_DATABASE_BACKUP} 2>/dev/null
      RET=$?
      if [[ $RET != 0 ]]; then
        echo "Something messed up with restore of ${ERP_DATABASE_BACKUP}."
        echo "May not be critical..."
      fi

      turn_on_plv8
    fi
  fi
}

setup_xtuplecommerce_db() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  psql -U postgres -c "CREATE USER xtuplecommerce SUPERUSER PASSWORD 'xtuplecommerce' IN GROUP xtrole;" 2>/dev/null
  psql -U postgres -c "ALTER USER xtuplecommerce SUPERUSER;" 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    echo "Warning or Fail on: CREATE USER xtuplecommerce. Already exists?"
  fi

  psql -At -U postgres -l | grep -q ${XTC_DATABASE_NAME} 2>/dev/null
  RET=$?
  if [[ $RET == 0 ]]; then
    echo "Database ${XTC_DATABASE_NAME} already exists"
  else
    echo "Creating ${XTC_DATABASE_NAME}!"
    createdb -U postgres -O xtuplecommerce -p 5432 ${XTC_DATABASE_NAME}

    if [[ ! -f ${WORKDIR}/db/${XTC_DATABASE_BACKUP} ]]; then
      echo "File not found! ${WORKDIR}/db/${XTC_DATABASE_BACKUP}"
      echo "Don't know what you want me to restore!"
    else
      pg_restore -U xtuplecommerce -d ${XTC_DATABASE_NAME} ${WORKDIR}/db/${XTC_DATABASE_BACKUP} 2>/dev/null
      RET=$?
      if [[ $RET != 0 ]]; then
        echo "Something messed up with restore of ${XTC_DATABASE_BACKUP}"
        echo "May not be critical"
      fi
    fi
  fi
}

install_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cd $WORKDIR

  if [ ! -d "/opt/xtuple/${MWC_VERSION}" ]; then
    echo "Directory /opt/xtuple/${MWC_VERSION} does not exist."

    sudo mkdir -p /opt/xtuple/${MWC_VERSION}
    echo "Directory /opt/xtuple/${MWC_VERSION} created"
  else
    echo "Directory /opt/xtuple/${MWC_VERSION} exists"
  fi

  cd $WORKDIR
  if [[ ! -f ${WORKDIR}/${ERP_MWC_TARBALL} ]]; then
    echo "Looking for ${WORKDIR}/${ERP_MWC_TARBALL}"
    echo "Not Found! This is kinda important..."
    exit 2
  else
    ERPTARDIR=$(tar -tzf ${ERP_MWC_TARBALL} | head -1 | cut -f1 -d"/")

    if [ ! -d "/etc/xtuple/${MWC_VERSION}" ]; then
      echo "Directory /etc/xtuple/${MWC_VERSION} DOES NOT exists."

      sudo mkdir -p /etc/xtuple/${MWC_VERSION}
      echo "Created Directory /etc/xtuple/${MWC_VERSION}"
    else
      echo "${MWC_VERSION} Directory exists"
    fi

    echo "Extracting ${ERP_MWC_TARBALL}"
    tar xf ${ERP_MWC_TARBALL}
    if [[ -d "/opt/xtuple/${MWC_VERSION}/xtupleerp" ]]; then
      echo "Moving existing xtupleerp directory to /opt/xtuple/${MWC_VERSION}/xtupleerp-${WORKDATE}"
      sudo mv /opt/xtuple/${MWC_VERSION}/xtupleerp /opt/xtuple/${MWC_VERSION}/xtupleerp-${WORKDATE}
    fi

    sudo cp -R ${WORKDIR}/${ERPTARDIR} /opt/xtuple/${MWC_VERSION}/xtupleerp
    sudo chown -R xtuple:xtuple /opt/xtuple/${MWC_VERSION}
    sudo cp -R ${WORKDIR}/${ERPTARDIR}/etc/init /etc
    sudo cp -R ${WORKDIR}/${ERPTARDIR}/etc/xtuple /etc/xtuple/${MWC_VERSION}/xtupleerp
    sudo chown -R xtuple:xtuple /etc/xtuple

    HAS_XTEXT=$(psql -At -U admin ${ERP_DATABASE_NAME} -c "SELECT count(*)
                 FROM pg_catalog.pg_class c
                 JOIN pg_namespace n ON n.oid= c.relnamespace
                WHERE nspname = 'xt' AND relname = 'ext';")
    if [[ $HAS_XTEXT == 1 ]]; then
      echo "${ERP_DATABASE_NAME} Has ext"
      EXT_LOCATIONS=$(psql -At -U admin ${ERP_DATABASE_NAME} -c "SELECT ext_location from xt.ext WHERE ext_location NOT IN ('/core-extensions','/private-extensions')")
      echo "$EXT_LOCATIONS"
      echo "Since xt.ext exists, we can try to preload things that may not exist.  There may be exceptions to doing this."
      psql -U admin -d xtupleerp -f ${WORKDIR}/sql/preload.sql

      sudo su - xtuple -c "cd /opt/xtuple/${MWC_VERSION}/xtupleerp/xtuple && ./scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/xtupleerp/config.js"

      RET=$?
      if [[ $RET != 0 ]]; then
        echo "BuildApp Died, So do we..."
        exit 2
      fi
    else
      echo "${ERP_DATABASE_NAME} Does Not have xt.ext"
      sudo su - xtuple -c "cd /opt/xtuple/${MWC_VERSION}/xtupleerp/xtuple && ./scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/xtupleerp/config.js"

      echo "now that xt.ext exists, we can run preload.sql so that we don't need to run build_app for all extensions over and over..."
      echo "There may be exceptions to this."
      psql -U admin -d xtupleerp -f ${WORKDIR}/sql/preload.sql
      echo "Running build_app for the extensions we preloaded into xt.ext"
      sudo su - xtuple -c "cd /opt/xtuple/${MWC_VERSION}/xtupleerp/xtuple && ./scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/xtupleerp/config.js"

      RET=$?
      if [[ $RET != 0 ]]; then
        echo "BuildApp Died, So do we..."
        exit 2
      fi
    fi

    echo "Lets try starting this..."
    sudo service xtuple-xtupleerp stop
    sudo service xtuple-xtupleerp start
    RET=$?
    if [[ $RET -ne 0 ]]; then
      echo "Something went wrong trying to run"
      echo "sudo service xtuple-xtupleerp start"
    fi

    echo "Updating the xTupleCommerce Login/Password"
    psql -U xtuplecommerce -d xtuplecommerce -f ${WORKDIR}/sql/setadmin.sql

    echo "Loading in the oa2client information"
    if [[ ! -f ${WORKDIR}/sql/oa2client.sql ]]; then
      echo "oa2client.sql not found. Generating it."
      generate_p12
      generateoasql
      psql -U admin -d xtupleerp -f ${WORKDIR}/sql/oa2client.sql
    else
      echo "oa2client.sql found. loading it."
      psql -U admin -d xtupleerp -f ${WORKDIR}/sql/oa2client.sql
    fi

    echo "Loading in the xd.site information"
    psql -U admin -d xtupleerp -f ${WORKDIR}/sql/xd_site.sql

    # (echo '127.0.0.1 '${NGINX_ECOM_DOMAIN} ${NGINX_SITE}'') | sudo tee -a /etc/hosts >/dev/null
    echo "Setting the local /etc/hosts file for 127.0.0.1 xtuple.xd"
    (echo '127.0.0.1 xtuple.xd') | sudo tee -a /etc/hosts >/dev/null
  fi
}

install_example_gateway() {
  psql -U admin -p 5432 ${ERP_DATABASE_NAME} -c "INSERT INTO paymentgateways.gateway (
                     gateway_name,        gateway_hostname,
                     gateway_base_path,   gateway_node_lib_name
           ) SELECT ${GATEWAY_NAME},      ${GATEWAY_HOSTNAME},
                    ${GATEWAY_BASE_PATH}, ${GATEWAY_NODE_LIB_NAME}
              WHERE NOT EXISTS (SELECT 1 FROM paymentgateways.gateway WHERE gateway_name = ${GATEWAY_NAME});"
}

setup_compass() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if type -p "compass" > /dev/null; then
    echo "Found compass"
  else
    echo "Need to install compass and ruby dependencies"

    sudo apt-get -q -y install rubygems-integration
    sudo gem install compass -v 0.12.7
    sudo gem install bootstrap-sass -v 3.2.0.1
  fi
}

setup_phpnginx() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if type -p "php" > /dev/null; then
   echo "php found"
  else
    echo "Need to install php5 and dependencies"

    sudo apt-get -y install nginx
    sudo apt-get -q -y install \
            php5-common \
            php5-fpm \
            php5-cli \
            php5 \
            php5-dev \
            php5-json \
            php5-gd \
            php5-pgsql \
            php5-curl \
            php5-intl \
            php5-mcrypt \
            php-apc
  fi

  if type -p "composer" > /dev/null; then
    echo "composer found"
  else 
    echo "Need to install composer and dependencies"

    curl -sS https://getcomposer.org/installer | php && \
    sudo mv composer.phar /usr/local/bin/composer

    composer config --global process-timeout 600
    composer config --global preferred-install dist
    composer config --global secure-http false
    composer config --global github-protocols https git ssh

  fi

  PHP_INI="/etc/php5/fpm/php.ini"

  grep -q '^error_reporting = E_ALL' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^error_reporting/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;error_reporting/ a\
error_reporting = E_ALL' ${PHP_INI}
  fi

  grep -q '^memory_limit = 256M' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^memory_limit/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;memory_limit/ a\
memory_limit = 256M' ${PHP_INI}
  fi

  grep -q '^php_value[memory_limit] = 256M' /etc/php5/fpm/pool.d/www.conf 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^;php_admin_value\[memory_limit\]/ a\
php_value[memory_limit] = 256M' /etc/php5/fpm/pool.d/www.conf
  fi

  grep -q 'upload_max_filesize = 64M' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^upload_max_filesize/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;upload_max_filesize/ a\
upload_max_filesize = 64M' ${PHP_INI}
  fi

  grep -q 'post_max_size = 64M' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^post_max_size/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;post_max_size/ a\
post_max_size = 64M' ${PHP_INI}
  fi

  grep -q '^max_input_vars = 100000' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^max_input_vars/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^; max_input_vars/ a\
max_input_vars = 100000' ${PHP_INI}
  fi

  grep -q '^date.timezone = ${TIMEZONE}' ${PHP_INI} 2>/dev/null
  RET=$?
    if [[ $RET != 0 ]]; then
  sudo sed -i '/^date.timezone/ s/^/;/' ${PHP_INI}
  sudo sed -i "/^;date.timezone/ a\
date.timezone = ${TIMEZONE}" ${PHP_INI}
  fi

  grep -q '^session.gc_probability = 1' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^session.gc_probability/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;session.gc_probability/ a\
session.gc_probability = 1' ${PHP_INI}
  fi

  grep -q '^session.gc_divisor = 100' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^session.gc_divisor/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;session.gc_divisor/ a\
session.gc_divisor = 100' ${PHP_INI}
  fi

  grep -q '^session.gc_maxlifetime = 200000' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^session.gc_maxlifetime/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;session.gc_maxlifetime/ a\
session.gc_maxlifetime = 200000' ${PHP_INI}
  fi

  grep -q '^session.cookie_lifetime = 2000000' ${PHP_INI} 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^session.cookie_lifetime/ s/^/;/' ${PHP_INI}
    sudo sed -i '/^;session.cookie_lifetime/ a\
session.cookie_lifetime = 2000000' ${PHP_INI}
  fi

  grep -q '^error_reporting = E_ALL' /etc/php5/cli/php.ini
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^error_reporting/ s/^/;/' /etc/php5/cli/php.ini
    sudo sed -i '/^;error_reporting/ a\
error_reporting = E_ALL' /etc/php5/cli/php.ini
  fi

  grep -q '^memory_limit = 512M' /etc/php5/cli/php.ini 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^memory_limit/ s/^/;/' /etc/php5/cli/php.ini
    sudo sed -i '/^;memory_limit/ a\
memory_limit = 512M' /etc/php5/cli/php.ini
  fi

  grep -q '^date.timezone = ${TIMEZONE}' /etc/php5/cli/php.ini 2>/dev/null
  RET=$?
  if [[ $RET != 0 ]]; then
    sudo sed -i '/^date.timezone/ s/^/;/' /etc/php5/cli/php.ini
    sudo sed -i "/^;date.timezone/ a\
date.timezone = ${TIMEZONE}" /etc/php5/cli/php.ini
  fi

  # Prep nginx

  sudo mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.original
  sudo cp ${WORKDIR}/nginx/nginx.conf /etc/nginx/

  sudo mv /etc/nginx/mime.types /etc/nginx/mime.types.original
  sudo cp ${WORKDIR}/nginx/mime.types /etc/nginx/

  sudo mv /etc/nginx/fastcgi_params /etc/nginx/fastcgi_params.original
  sudo cp ${WORKDIR}/nginx/fastcgi_params /etc/nginx/

  sudo cp -R ${WORKDIR}/nginx/apps /etc/nginx/
  sudo cp -R ${WORKDIR}/nginx/conf.d/* /etc/nginx/conf.d/

  # Set default domain to return 404 for non-setup URLs
  sudo cp ${WORKDIR}/nginx/sites-available/default.conf.template /etc/nginx/sites-available/default.http.conf && \
  sudo ln -s /etc/nginx/sites-available/default.http.conf /etc/nginx/sites-enabled/default.http.conf

  sudo cp ${WORKDIR}/nginx/sites-available/xtuple.xd.conf.template /etc/nginx/sites-available/xtuple.xd.conf && \
  sudo ln -s /etc/nginx/sites-available/xtuple.xd.conf /etc/nginx/sites-enabled/xtuple.xd.conf

  if [ ! -d "/var/log/nginx/xtuple.xd" ]; then
    echo "Directory /var/log/nginx/xtuple.xd DOES NOT exists."
    sudo mkdir -p /var/log/nginx/xtuple.xd/
  fi

  sudo rm /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default 2>&1 >/dev/null

  sudo service php5-fpm restart
  sudo service nginx    restart
}

setup_phpunit() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  # PHPUnit
  if type -p  "phpunit" > /dev/null; then
    echo "phpunit found"
  else
    echo "Installing phpunit and dependencies"

    wget https://phar.phpunit.de/phpunit-old.phar && \
    chmod +x phpunit-old.phar && \
    sudo mv phpunit-old.phar /usr/local/bin/phpunit
  fi
}

setup_xtuplecommerce() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if [[ ! -f ${WORKDIR}/${XTC_WWW_TARBALL} ]]; then
    echo "Looking for: ${XTC_WWW_TARBALL}"
    echo "Can't find it... This is important"
    exit 2
  else
    if [ ! -d "/var/www" ]; then
      echo "Directory /var/www does not exist."
      sudo mkdir -p /var/www
      echo "Directory /var/www created."
    else
      echo "/var/www already exists"
    fi

    cd $WORKDIR
    XTCTARDIR=$(tar -tzf ${XTC_WWW_TARBALL} | head -1 | cut -f1 -d"/")

    echo "Extracting ${XTC_WWW_TARBALL}"
    tar xf ${XTC_WWW_TARBALL}
    if [[ -d "/var/www/xTupleCommerce" ]]; then
      echo "Moving old /var/www/xTupleCommerce directory to /var/www/xTupleCommerce-${WORKDATE}"
      sudo mv /var/www/xTupleCommerce /var/www/xTupleCommerce-${WORKDATE}
    fi

    sudo mv $WORKDIR/${XTCTARDIR} /var/www/xTupleCommerce
    sudo chown -R www-data:www-data /var/www/xTupleCommerce
  fi
}

webnotes() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if type -p "ec2metadata" > /dev/null; then
    #prefer this if we have it and we're on EC2...
    IP=$(ec2metadata --public-ipv4)
  else
    IP=$(ip -f inet -o addr show eth0|cut -d\  -f 7 | cut -d/ -f 1)
  fi

  if [[ -z ${IP} ]]; then
    IP="The IP of This Machine"
  fi

cat << EOF > xtuplecommerce_connection.log
     ************************************"
     ***** IMPORTANT!!! PLEASE READ *****"
     ************************************"
 
     Here is the information to get logged in!
 
     First, Add the following to your system's hosts file
     Windows: %SystemRoot%\System32\drivers\etc\hosts
     OSX/Linux: /etc/hosts
     
     ${IP} xtuple.xd
 
     Here is where you can login:
     xTuple Desktop Client v${MWC_VERSION}:
     Server: ${IP}
     Port: 5432
     Database: xtupleerp
     User: admin
     Pass: admin
    
 
     xTuple Mobile Web Client/REST:
     Login at: http://xtuple.xd:8888
     Login at: https://xtuple.xd:8443
     User: admin
     Pass: admin
 
     Ecommerce Site Login:
     Login at http://xtuple.xd/login
     User: Developer
     Pass: admin

     Nginx Config: 
     Webroot: /var/www/xTupleCommerce/drupal/core
 
  Please set your nginx config for the xTupleCommerce webroot to:
  root /var/www/xTupleCommerce/drupal/core;
EOF
  cat xtuplecommerce_connection.log
}

destroy_env() {
  echo "About to delete the following"
}

# Uncomment for testing specific functions.
# if [[ -z $1 ]]; then
# echo "OK"
#else
#  $1
#  exit 0
#fi

dont_touch() {
  read_configs
  setup_sudo
  # initial_update
  add_mwc_user
  install_npm_node
  install_postgresql
  setup_postgresql_cluster
  setup_erp_db
  setup_xtuplecommerce_db
  install_mwc
  # install_example_gateway
  setup_phpunit
  setup_compass
  setup_phpnginx
  setup_xtuplecommerce
  clear
  webnotes
}

xtau_deploy_mwc() {
  read_xtau_configs
}
