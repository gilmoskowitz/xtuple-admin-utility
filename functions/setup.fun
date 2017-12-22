#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

export WORKDIR=$(pwd)
export DEPLOYER_NAME=$(whoami)

WORKDAY=$(date "+%m%d%y")
WORKDATE=$(date "+%m%d%y-%s")
GITHUB_TOKEN=$(git config --get github.token)

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
  fi

  sudo n 0.10.40
  sudo npm install -g npm@2.x.x
  sudo npm install -g browserify
}

check_npm() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cd $WORKDIR

  if type -p "npm" > /dev/null; then
    echo "Found npm, checking version"
    NPM_VER=$(npm -v | grep -q '^2')
    if [[ -z "$NPM_VER" ]] ; then
      install_npm_node
    fi
  else
    echo "installed npm version ok."
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
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  # THE P12 KEY OUT NEEDS TO GO IN /var/xtuple/keys/
  # NGINX_ECOM_DOMAIN='xTupleCommerce'
  # ECOMM_ADMIN_EMAIL="admin@xtuple.xd"
  # ERP_SITE_URL='xtuple.xd'

  KEY_P12_PATH=${WORKDIR}/private
  KEYTMP=${KEY_P12_PATH}/tmp
  mkdir -p ${KEY_P12_PATH}
  mkdir -p ${KEYTMP}
  rm -rf ${KEYTMP}/*.key
  rm -rf ${KEYTMP}/*.csr
  rm -rf ${KEYTMP}/*.p12
  rm -rf ${KEYTMP}/*.pem
  rm -rf ${KEYTMP}/*.crt

  NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12
  export NGINX_ECOM_DOMAIN_P12=${NGINX_ECOM_DOMAIN}.p12

  ssh-keygen -t rsa -b 2048 -C "${ECOMM_ADMIN_EMAIL}" -f ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key -P ''
  openssl req -batch -new -key ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key -out ${KEYTMP}/${NGINX_ECOM_DOMAIN}.csr
  openssl x509 -req -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}.csr -signkey ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key -out ${KEYTMP}/${NGINX_ECOM_DOMAIN}.crt
  openssl pkcs12 -export -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}.crt -inkey ${KEYTMP}/${NGINX_ECOM_DOMAIN}.key -out ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -password pass:notasecret
  openssl pkcs12 -in ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} -passin pass:notasecret -nocerts -nodes | openssl rsa > ${KEYTMP}/${NGINX_ECOM_DOMAIN}_private.pem
  openssl rsa -in ${KEYTMP}/${NGINX_ECOM_DOMAIN}_private.pem -passin pass:notasecret -pubout -passout pass:notasecret > ${KEYTMP}/${NGINX_ECOM_DOMAIN}_public.pem
  cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${KEY_P12_PATH}

  OAPUBKEY=$(<${KEYTMP}/${NGINX_ECOM_DOMAIN}_public.pem)
  export OAPUBKEY=${OAPUBKEY}
  echo "Created OAPUBKEY"
}

generateoasql() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  cat << EOF > ${WORKDIR}/sql/oa2client.sql
  DELETE FROM xt.oa2client WHERE oa2client_client_x509_pub_cert='${OAPUBKEY}';

  INSERT INTO xt.oa2client(oa2client_client_id, oa2client_client_secret, oa2client_client_name, \
  oa2client_client_email, oa2client_client_web_site, oa2client_client_type, oa2client_active, \
  oa2client_issued, oa2client_delegated_access, oa2client_client_x509_pub_cert, oa2client_org) \
  SELECT 'xTupleCommerceID' AS oa2client_client_id, xt.uuid_generate_v4() AS oa2client_client_secret, \
  '${NGINX_ECOM_DOMAIN}' AS oa2client_client_name, '${ECOMM_ADMIN_EMAIL}' AS oa2client_client_email, \
  '${ERP_SITE_URL}' AS oa2client_client_web_site, 'jwt bearer' AS oa2client_client_type, TRUE AS oa2client_active,  \
  now() AS oa2client_issued , TRUE AS oa2client_delegated_access, '${OAPUBKEY}' AS oa2client_client_x509_pub_cert, current_database() \
  AS  oa2client_org \
  WHERE NOT EXISTS ( SELECT 1 FROM xt.oa2client WHERE oa2client_client_x509_pub_cert='${OAPUBKEY}');
EOF

  cat << EOF > ${WORKDIR}/sql/xd_site.sql
  DELETE FROM xdruple.xd_site;
  INSERT INTO xdruple.xd_site(xd_site_name, xd_site_url, xd_site_notes) \
  SELECT '${ERP_APPLICATION}','http://${DOMAIN}','ecomm site' \
  WHERE NOT EXISTS (SELECT 1 FROM xdruple.xd_site WHERE xd_site_name = '${ERP_APPLICATION}' AND xd_site_url='http://${DOMAIN}' AND xd_site_notes='ecomm site');
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

config_mwc_scripts() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
if [[ -z $NGINX_PORT ]]; then
export NGINX_PORT=8443
echo "Using port 8443 for Node.js https requests"
fi

if [[ -z $PGPORT ]]; then
export PGPORT=5432
echo "Using port 5432 for PostgreSQL"
fi

    if [ ! -f /opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple/node-datasource/sample_config.js ]; then
        log "Hrm, sample_config.js doesn't exist.. something went wrong. check the output/log and try again"
        do_exit
    fi

    export XTDIR=/opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple

    sudo rm -rf /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"
    log_exec sudo mkdir -p /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private

    # setup encryption details
    log_exec sudo touch /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt
    log_exec sudo touch /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt
    log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"
    # temporarily so we can cat to them since bash is being a bitch about quoting the trim string below
    log_exec sudo chmod 777 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt
    log_exec sudo chmod 777 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt

    cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt
    cat /dev/urandom | tr -dc '0-9a-zA-Z!@#$%^&*_+-'| head -c 64 > /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt

    log_exec sudo chmod 660 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt
    log_exec sudo chmod 660 /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt

    log_exec sudo openssl genrsa -des3 -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.key -passout pass:xtuple 4096
    log_exec sudo openssl rsa -in /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.key -passin pass:xtuple -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem -passout pass:xtuple
    log_exec sudo openssl req -batch -new -key /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.csr -subj '/CN='$(hostname)
    log_exec sudo openssl x509 -req -days 365 -in /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.csr -signkey /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem -out /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.crt

    log_exec sudo cp /opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple/node-datasource/sample_config.js /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

    log_exec sudo sed -i  "/encryptionKeyFile/c\      encryptionKeyFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/encryption_key.txt\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
    log_exec sudo sed -i  "/keyFile/c\      keyFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/key.pem\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
    log_exec sudo sed -i  "/certFile/c\      certFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/server.crt\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
    log_exec sudo sed -i  "/saltFile/c\      saltFile: \"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/private/salt.txt\"," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

    log "Using database $ERP_DATABASE_NAME"
    log_exec sudo sed -i  "/databases:/c\      databases: [\"$ERP_DATABASE_NAME\"]," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js
    log_exec sudo sed -i  "/port: 5432/c\      port: $PGPORT," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

    log_exec sudo sed -i  "/port: 8443/c\      port: $NGINX_PORT," /etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js

    log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} /etc/xtuple

    if [ $DISTRO = "ubuntu" ]; then
        case "$CODENAME" in
            "trusty") ;&
            "utopic")
                log "Creating upstart script using filename /etc/init/xtuple-$ERP_DATABASE_NAME.conf"
                # create the upstart script
                sudo cp $WORKDIR/templates/ubuntu-upstart /etc/init/xtuple-"$ERP_DATABASE_NAME".conf
                log_exec sudo bash -c "echo \"chdir /opt/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource\" >> /etc/init/xtuple-\"$ERP_DATABASE_NAME\".conf"
                log_exec sudo bash -c "echo \"exec ./main.js -c /etc/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/config.js > /var/log/node-datasource-$MWC_VERSION-\"$ERP_DATABASE_NAME\".log 2>&1\" >> /etc/init/xtuple-\"$ERP_DATABASE_NAME\".conf"
                ;;
            "vivid") ;&
            "xenial")
                log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$ERP_DATABASE_NAME.service"
                sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$ERP_DATABASE_NAME".service
                log_exec sudo bash -c "echo \"User=${DEPLOYER_NAME}\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
                log_exec sudo bash -c "echo \"Group=${DEPLOYER_NAME}\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
                log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$ERP_DATABASE_NAME\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
                log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
                ;;
        esac
    elif [ $DISTRO = "debian" ]; then
        case "$CODENAME" in
            "wheezy")
                log "Creating debian init script using filename /etc/init.d/xtuple-$ERP_DATABASE_NAME"
                # create the weird debian sysvinit style script
                sudo cp $WORKDIR/templates/debian-init /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
                log_exec sudo sed -i  "/APP_DIR=/c\APP_DIR=\"/opt/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/xtuple/node-datasource\"" /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
                log_exec sudo sed -i  "/CONFIG_FILE=/c\CONFIG_FILE=\"/etc/xtuple/$MWC_VERSION/"$ERP_DATABASE_NAME"/config.js\"" /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
                # should be +x from git but just in case...
                sudo chmod +x /etc/init.d/xtuple-"$ERP_DATABASE_NAME"
                ;;
            "jessie")
                log "Creating systemd service unit using filename /etc/systemd/system/xtuple-$ERP_DATABASE_NAME.service"
                sudo cp $WORKDIR/templates/xtuple-systemd.service /etc/systemd/system/xtuple-"$ERP_DATABASE_NAME".service
                log_exec sudo bash -c "echo \"SyslogIdentifier=xtuple-$ERP_DATABASE_NAME\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
                log_exec sudo bash -c "echo \"ExecStart=/usr/local/bin/node /opt/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/xtuple/node-datasource/main.js -c /etc/xtuple/$MWC_VERSION/\"$ERP_DATABASE_NAME\"/config.js\" >> /etc/systemd/system/xtuple-\"$ERP_DATABASE_NAME\".service"
                ;;
        esac
    else
        log "Seriously? We made it all the way to where I need to write out the init script and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
        do_exit
    fi
}

get_environment() {
  upgrade_database

  DEPLOYER_NAME=${DEPLOYER_NAME}

  ERP_DATABASE_NAME=${DATABASE}
  ERP_ISS="xTupleCommerceID"

  SITE_TEMPLATE="flywheel"
  ERP_APPLICATION="xTupleCommerce"
  ERP_DEBUG="true"
  WENVIRONMENT="stage"

  DOMAIN=${SITE_TEMPLATE}.xd
  DOMAIN_ALIAS=${SITE_TEMPLATE}.xtuple.net
  HTTP_AUTH_NAME="Developer"
  HTTP_AUTH_PASS="ChangeMe"
  ERP_HOST=https://${DOMAIN}:8443

  : ${DIALOG_OK=0}
  : ${DIALOG_CANCEL=1}
  : ${DIALOG_HELP=2}
  : ${DIALOG_EXTRA=3}
  : ${DIALOG_ITEM_HELP=4}
  : ${DIALOG_ESC=255}

  dialog --ok-label "Submit" \
            --backtitle "xTuple Web Client Setup" \
            --title "Configuration" \
            --form "Configure Web Client Environment" \
  0 0 0 \
           "ERP Host:"  1 1          "${ERP_HOST}"   1 20 50 0 \
       "ERP Database:"  2 1 "${ERP_DATABASE_NAME}"   2 20 50 0 \
     "OAuth Token Id:"  3 1           "${ERP_ISS}"   3 20 50 0 \
        "Application:"  4 1   "${ERP_APPLICATION}"   4 20 50 0 \
           "Web Repo:"  5 1     "${SITE_TEMPLATE}"   5 20 50 0 \
          "ERP Debug:"  6 1         "${ERP_DEBUG}"   6 20 50 0 \
        "Environment:"  7 1      "${WENVIRONMENT}"   7 20 50 0 \
             "Domain:"  8 1            "${DOMAIN}"   8 20 50 0 \
       "Domain Alias:"  9 1      "${DOMAIN_ALIAS}"   9 20 50 0 \
     "HTTP Auth User:" 10 1    "${HTTP_AUTH_NAME}"  10 20 50 0 \
     "HTTP Auth Pass:" 11 1    "${HTTP_AUTH_PASS}"  11 20 50 0 \
      "Deployer Name:" 12 0     "${DEPLOYER_NAME}"  12 20 50 0 \
       "Github Token:" 13 0      "${GITHUB_TOKEN}"  13 20 50 0 \
  3>&1 1>&2 2>&3 2> xtuple_webclient.ini
  return_value=$?

  case $return_value in
    $DIALOG_OK)

  read -d "\n" ERP_HOST ERP_DATABASE_NAME ERP_ISS ERP_APPLICATION SITE_TEMPLATE ERP_DEBUG WENVIRONMENT DOMAIN DOMAIN_ALIAS HTTP_AUTH_NAME HTTP_AUTH_PASS DEPLOYER_NAME GITHUB_TOKEN <<<$(cat xtuple_webclient.ini);

  export ERP_HOST=${ERP_HOST}
  export ERP_DATABASE_NAME=${ERP_DATABASE_NAME}
  export ERP_ISS=${ERP_ISS}
  export ERP_APPLICATION=${ERP_APPLICATION}
  export SITE_TEMPLATE=${SITE_TEMPLATE}
  export ERP_DEBUG=${ERP_DEBUG}
  export WENVIRONMENT=${WENVIRONMENT}
  export DOMAIN=${DOMAIN}
  export DOMAIN_ALIAS=${DOMAIN_ALIAS}
  export HTTP_AUTH_NAME=${HTTP_AUTH_NAME}
  export HTTP_AUTH_PASS=${HTTP_AUTH_PASS}
  export DEPLOYER_NAME=${DEPLOYER_NAME}
  export GITHUB_TOKEN=${GITHUB_TOKEN}
  export ERP_SITE_URL=${DOMAIN}
  export NGINX_ECOM_DOMAIN=${DOMAIN}
  export ECOMM_ADMIN_EMAIL=admin@${DOMAIN}
  ;;
    $DIALOG_CANCEL)
   main_menu
  ;;
    $DIALOG_HELP)
      echo "Help pressed.";;
    $DIALOG_EXTRA)
      echo "Extra button pressed.";;
    $DIALOG_ITEM_HELP)
      echo "Item-help button pressed.";;
    $DIALOG_ESC)
     main_menu
      ;;
  esac
}

get_xtc_environment() {
  #get_environment

  ECOMM_EMAIL=admin@${DOMAIN}
  ECOMM_SITE_NAME='xTupleCommerceSite'
  ECOMM_DB_NAME=${ERP_DATABASE_NAME}_xtc
  ECOMM_DB_USERNAME="${ERP_DATABASE_NAME}_admin"
  ECOMM_DB_USERPASS="ChangeMe"

  : ${DIALOG_OK=0}
  : ${DIALOG_CANCEL=1}
  : ${DIALOG_HELP=2}
  : ${DIALOG_EXTRA=3}
  : ${DIALOG_ITEM_HELP=4}
  : ${DIALOG_ESC=255}

  dialog --ok-label "Submit" \
            --backtitle "xTupleCommerce Setup" \
            --title "Configuration" \
            --form "Configure xTupleCommerce Environment" \
  0 0 0 \
           "Site Email:"    1 1              "${ECOMM_EMAIL}"   1 20 50 0 \
       "Site Name:"         2 1          "${ECOMM_SITE_NAME}"   2 20 50 0 \
   "Ecomm Database Name:"   3 1            "${ECOMM_DB_NAME}"   3 20 50 0 \
        "Site DB Pg User:"  4 1        "${ECOMM_DB_USERNAME}"   4 20 50 0 \
        "Site DB Pg Pass:"  5 1        "${ECOMM_DB_USERPASS}"   5 20 50 0 \
  3>&1 1>&2 2>&3 2> xtuple_commerce.ini
  return_value=$?

  case $return_value in
    $DIALOG_OK)
      read -d "\n" ECOMM_EMAIL ECOMM_SITE_NAME ECOMM_DB_NAME ECOMM_DB_USERNAME ECOMM_DB_USERPASS <<<$(cat xtuple_commerce.ini);

      export ECOMM_EMAIL=${ECOMM_EMAIL}
      export ECOMM_SITE_NAME=${ECOMM_SITE_NAME}
      export ECOMM_DB_NAME=${ECOMM_DB_NAME}
      export ECOMM_DB_USERNAME=${ECOMM_DB_USERNAME}
      export ECOMM_DB_USERPASS=${ECOMM_DB_USERPASS}
      export ECOMM_ADMIN_EMAIL=${ECOM_EMAIL}
      ;;
    $DIALOG_CANCEL)
      main_menu
      ;;
    $DIALOG_HELP)
      echo "Help pressed.";;
    $DIALOG_EXTRA)
      echo "Extra button pressed.";;
    $DIALOG_ITEM_HELP)
      echo "Item-help button pressed.";;
    $DIALOG_ESC)
    main_menu
      ;;
  esac
}

install_mwc() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  unset APPLY_FOUNDATION

  if [[ $ISXTAU ]]; then
    get_environment

    psql -At -U postgres -l | grep -q ${ERP_DATABASE_NAME} 2>/dev/null
    RET=$?
    if [[ $RET == 0 ]]; then
      echo "Database ${ERP_DATABASE_NAME} already exists, good!"
      export ERP_DATABASE=${ERP_DATABASE_NAME}
    else
      echo "Creating ${ERP_DATABASE_NAME}!"
      createdb -U admin -p ${PGPORT} ${ERP_DATABASE_NAME}
      psql -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "CREATE EXTENSION plv8;"
    fi
  fi

  cd $WORKDIR
  if [[ ! -f ${WORKDIR}/${ERP_MWC_TARBALL} ]]; then
    echo "Looking for ${WORKDIR}/${ERP_MWC_TARBALL}"
    echo "Not Found! This is kinda important..."
    exit 2
  fi

  ERPTARDIR=$(tar -tzf ${ERP_MWC_TARBALL} | head -1 | cut -f1 -d"/")

  if [ -z "$(ls -A ${ERPTARDIR})" ]; then
    echo "${ERPTARDIR} is empty or does not exist\nExtracting ${ERP_MWC_TARBALL}"
    tar xf ${ERP_MWC_TARBALL}
    THIS_ERP_VER=$(cd ${ERPTARDIR}/xtuple && git describe --abbrev=0 --tags)
    MWC_VERSION=${THIS_ERP_VER}
  else
    echo "${ERPTARDIR} Exists and is not empty."
    THIS_ERP_VER=$(cd ${ERPTARDIR}/xtuple && git describe --abbrev=0 --tags)
    MWC_VERSION=${THIS_ERP_VER}
  fi

  if [ ! -d "/etc/xtuple/${MWC_VERSION}" ]; then
    echo "Directory /etc/xtuple/${MWC_VERSION} DOES NOT exists."
    sudo mkdir -p /etc/xtuple/${MWC_VERSION}
    echo "Created Directory /etc/xtuple/${MWC_VERSION}"
  else
    echo "${MWC_VERSION} Directory exists"
  fi

  if [[ -d "/opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}" ]]; then
    echo "Moving existing ${ERP_DATABASE_NAME} directory to /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}-${WORKDATE}"
    sudo mv /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME} /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}-${WORKDATE}

    echo "Copying ${WORKDIR}/${ERPTARDIR} to /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}"
    sudo cp -R ${WORKDIR}/${ERPTARDIR} /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}
    sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /opt/xtuple/${MWC_VERSION}
  else
    echo "Creating /opt/xtuple/${MWC_VERSION}"
    sudo mkdir -p /opt/xtuple/${MWC_VERSION}
    echo "Copying ${WORKDIR}/${ERPTARDIR} to /opt/xtuple/${MWC_VERSION}"
    sudo cp -R ${WORKDIR}/${ERPTARDIR} /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}
    echo "Setting owner to ${DEPLOYER_NAME} on /opt/xtuple/${MWC_VERSION}"
    sudo chown -R ${DEPLOYER_NAME}:${DEPLOYER_NAME} /opt/xtuple/${MWC_VERSION}
  fi

  config_mwc_scripts

  HAS_XTEXT=$(psql -At -U admin ${ERP_DATABASE_NAME} -c "SELECT count(*)
               FROM pg_catalog.pg_class c
               JOIN pg_namespace n ON n.oid= c.relnamespace
              WHERE nspname = 'xt' AND relname = 'ext';")

  export XTAPP=$(psql -At -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "SELECT fetchmetrictext('Application');")
  if [[ ${XTAPP} == "PostBooks" ]]; then
    APPLY_FOUNDATION='-f'
  fi

  export XTVER=$(psql -At -U admin -p ${PGPORT} ${ERP_DATABASE_NAME} -c "SELECT fetchmetrictext('ServerVersion');")

  if [[ $HAS_XTEXT == 1 ]]; then
    echo "${ERP_DATABASE_NAME} Has ext"
    EXT_LOCATIONS=$(psql -At -U admin ${ERP_DATABASE_NAME} -c "SELECT ext_location from xt.ext WHERE ext_location NOT IN ('/core-extensions','/private-extensions')")
    echo "$EXT_LOCATIONS"
    echo "Since xt.ext exists, we can try to preload things that may not exist.  There may be exceptions to doing this."
    psql -U admin -d xtupleerp -f ${WORKDIR}/sql/preload.sql

    log_exec sudo su - ${DEPLOYER_NAME}  -c "cd /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/xtuple && ./scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/xtupleerp/config.js ${APPLY_FOUNDATION}" 2>&1 | tee buildapp_output.log
    RET=$?
    if [[ $RET -ne 0 ]]; then
      msgbox "$(cat buildapp_output.log)"
      main_menu
    else
      msgbox "$(cat buildapp_output.log)"
    fi

  else
    echo "${ERP_DATABASE_NAME} Does Not have xt.ext"
    log_exec sudo su - ${DEPLOYER_NAME}  -c "cd /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/xtuple && ./scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/xtupleerp/config.js ${APPLY_FOUNDATION}" 2>&1 | tee buildapp_output.log
    RET=$?
    if [[ $RET -ne 0 ]]; then
      msgbox "$(cat buildapp_output.log)"
      main_menu
    else
      msgbox "$(cat buildapp_output.log)"
    fi

    # We can check for the private extensions dir...
    if [ -d /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/private-extensions ] && [ ${APPLY_FOUNDATION} == '-f' ]; then
      log_exec sudo su - ${DEPOLYER_NAME} -c "cd /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/xtuple && ./scripts/build_app.js -c /etc/xtuple/$MWC_VERSION/${ERP_DATABASE_NAME}/config.js -e ../private-extensions/source/inventory ${APPLY_FOUNDATION}" 2>&1 | tee buildapp_output.log
      RET=$?
      if [[ $RET -ne 0 ]]; then
        msgbox "$(cat buildapp_output.log)"
        main_menu
      else
        msgbox "$(cat buildapp_output.log)"
      fi
    else
      msgbox "Private-Extensions does not exists. You need to contact xTuple for access on github."
      main_menu
    fi

    echo " NEED STATUS HERE if build app succeeded or not, then load preload.sql..."
    echo "now that xt.ext exists, we can run preload.sql so that we don't need to run build_app for all extensions over and over..."
    echo "There may be exceptions to this."
    psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/preload.sql
    echo "Running build_app for the extensions we preloaded into xt.ext"

    log_exec sudo su - ${DEPLOYER_NAME} -c "cd /opt/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/xtuple && ./scripts/build_app.js -c /etc/xtuple/${MWC_VERSION}/${ERP_DATABASE_NAME}/config.js" 2>&1 | tee buildapp_output.log
    RET=$?
    if [[ $RET -ne 0 ]]; then
      msgbox "$(cat buildapp_output.log)"
      main_menu
    else
      msgbox "$(cat buildapp_output.log)"
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
}

load_oauth_site() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  echo "Loading in the oa2client information"
  generate_p12
  generateoasql

  psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/oa2client.sql
  psql -U admin -p ${PGPORT} -d ${ERP_DATABASE_NAME} -f ${WORKDIR}/sql/xd_site.sql
}

stop_mwc() {
  # Let's stop this service if running.
  echo "Stopping any node.js for this instance"
  sudo service xtuple-${ERP_DATABASE_NAME} stop
}

start_mwc() {
  echo "Lets try starting this..."
  sudo service xtuple-${ERP_DATABASE_NAME} stop
  sudo service xtuple-${ERP_DATABASE_NAME} start
  RET=$?
  if [[ $RET -ne 0 ]]; then
    echo "Something went wrong trying to run"
    echo "sudo service xtuple-${ERP_DATABASE_NAME} start"
  else
    msgbox "service xtuple-${ERP_DATABASE_NAME} started successfully"
  fi
}

config_xtc() {
  echo "Updating the xTupleCommerce Login/Password"
  psql -U xtuplecommerce -d xtuplecommerce -f ${WORKDIR}/sql/setadmin.sql

  # (echo '127.0.0.1 ${NGINX_ECOM_DOMAIN} ${NGINX_SITE} ) | sudo tee -a /etc/hosts >/dev/null
  echo "Setting the local /etc/hosts file for 127.0.0.1 xtuple.xd"
  (echo '127.0.0.1 xtuple.xd') | sudo tee -a /etc/hosts >/dev/null
}

install_example_gateway() {
  psql -U admin -p 5432 ${ERP_DATABASE_NAME} -c "INSERT INTO paymentgateways.gateway (
                     gateway_name,        gateway_hostname,
                     gateway_base_path,   gateway_node_lib_name
           ) SELECT ${GATEWAY_NAME},      ${GATEWAY_HOSTNAME},
                    ${GATEWAY_BASE_PATH}, ${GATEWAY_NODE_LIB_NAME}
              WHERE NOT EXISTS (SELECT 1 FROM paymentgateways.gateway WHERE gateway_name = ${GATEWAY_NAME});"
}

setup_compass() 
{
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  source ${SCRIPTS_DIR}/ruby.sh
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

setup_flywheel() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  get_environment
  get_xtc_environment
  setup_xdruple_nginx
  setup_compass

  start_mwc

  SITE_ENVS='dev stage live'

  SITE_ENV_TMP_WORK=${WORKING}/xdruple-sites/${ERP_DATABASE_NAME}

  mkdir -p ${SITE_ENV_TMP_WORK}

  SITE_ENV_TMP=${SITE_ENV_TMP_WORK}/${WENVIRONMENT}

  SITE_ROOT=/var/www

  # The site template developer
  SITE_DEV=xtuple

  SITE_TEMPLATE_TAG=xtau

  SITE_WEBROOT=${SITE_ROOT}/${WENVIRONMENT}

  if [ -n ${NGINX_ECOM_DOMAIN_P12} ]; then
    #generate_p12
    #generateoasql

    load_oauth_site
  else
    echo "DOMAIN NOT SET-EXITING!"
    do_exit
  fi

  KEY_PATH=/var/xtuple/keys
  sudo mkdir -p ${KEY_PATH}

  ERP_KEY_FILE_PATH=${KEY_PATH}/${NGINX_ECOM_DOMAIN_P12}

  log_exec sudo chown -R ${DEPLOYER_NAME}.${DEPLOYER_NAME} ${SITE_ROOT}

  {
  echo -e "XXX\n0\nCloning ${SITE_TEMPLATE} to ${SITE_ENV_TMP}\nXXX"
  log_exec sudo su - ${DEPLOYER_NAME} -c "git clone https://${GITHUB_TOKEN}:x-oauth-basic@github.com/${SITE_DEV}/${SITE_TEMPLATE} ${SITE_ENV_TMP}" 2>/dev/null
  echo -e "XXX\n10\nCloning ${SITE_TEMPLATE} to ${SITE_ENV_TMP}... Done.\nXXX"
  sleep 1

  echo -e "XXX\n10\nRunning submodule update\nXXX"
  log_exec sudo su - ${DEPLOYER_NAME} -c "cd ${SITE_ENV_TMP} && git submodule update --init --recursive" 2>/dev/null
  echo -e "XXX\n15\nRunning submodule udpate... Done.\nXXX"
  sleep 1

  echo -e "XXX\n15\nRunning composer install\nXXX"
  sleep 2
  # Check for composer token
  GITHUB_TOKEN=`git config --get github.token`
  cat << EOF > /home/${DEPLOYER_NAME}/.composer/config.json
  {
    "config": {
      "github-oauth": {
      "github.com": "$GITHUB_TOKEN" },
      "process-timeout": 600,
      "preferred-install": "source",
      "github-protocols": ["ssh", "https", "git"],
      "secure-http": false
    }
  }
EOF

  log_exec sudo su - ${DEPLOYER_NAME} -c "cd ${SITE_ENV_TMP} && composer install" 2>/dev/null
  echo -e "XXX\n30\nRunning composer install... Done\nXXX"
  sleep 1

  echo -e "XXX\n50\nWriting out environment.xml\nXXX"
  sleep 2
  ERP_DATABASE=${ERP_DATABASE_NAME}
  tee ${SITE_ENV_TMP}/application/config/environment.xml <<EOF
  <?xml version="1.0" encoding="UTF-8" ?>
  <environment type="${WENVIRONMENT}"
               xmlns="https://xdruple.xtuple.com/schema/environment"
               xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xsi:schemaLocation="https://xdruple.xtuple.com/schema/environment schema/environment.xsd">
    <xtuple host="${ERP_HOST}"
            database="${ERP_DATABASE}"
            iss="${ERP_ISS}"
            key="${ERP_KEY_FILE_PATH}"
            application="${ERP_APPLICATION}"
            debug="${ERP_DEBUG}"/>
  </environment>
EOF

  echo -e "XXX\n60\nWriting out environment.xml... Done\nXXX"
  sleep 1

  echo -e "XXX\n60\nCopying ${ERP_KEY_FILE_PATH}\nXXX"
  sleep 2
  cp ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} ${ERP_KEY_FILE_PATH} 2>/dev/null
  echo -e "XXX\n70\nCopying ${KEYTMP}/${NGINX_ECOM_DOMAIN_P12} to ${ERP_KEY_FILE_PATH}...Done\nXXX"
  sleep 1


  echo -e "XXX\n70\nSetting /etc/hosts\nXXX"
  sleep 2
  (echo '127.0.0.1' ${DOMAIN} ${DOMAIN_ALIAS} dev.${DOMAIN_ALIAS} stage.${DOMAIN_ALIAS} live.${DOMAIN_ALIAS}) | sudo tee -a /etc/hosts >/dev/null
  echo -e "XXX\n80\nSetting /etc/hosts...Done\nXXX"
  sleep 2

  echo -e "XXX\n80\nMoving WENVIRONMENT=${WENVIRONMENT}\nXXX"
  log_exec sudo su - ${DEPLOYER_NAME} -c "mv ${SITE_ROOT}/${WENVIRONMENT} ${SITE_ROOT}/${WENVIRONMENT}_${WORKDATE}"

  log_exec sudo su - ${DEPLOYER_NAME} -c "mv ${SITE_ENV_TMP} ${SITE_WEBROOT}"

  echo -e "XXX\n80\nRunning console.php install:drupal\nXXX"

  ( echo ./console.php install:drupal  --db-name=${ECOMM_DB_NAME} --db-pass=${ECOMM_DB_USERPASS}   --db-user=${ECOMM_DB_USERNAME}  --user-pass=${ECOMM_DB_USERPASS}  --site-mail=${ECOMM_EMAIL}  --site-name=${ECOMM_SITE_NAME} )| tee -a ${SITE_WEBROOT}/console_cmd.sh

  log_exec sudo su - ${DEPLOYER_NAME} -c "cd ${SITE_WEBROOT} && ./console.php install:drupal  --db-name=${ECOMM_DB_NAME} --db-pass=${ECOMM_DB_USERPASS}   --db-user=${ECOMM_DB_USERNAME}  --user-pass=${ECOMM_DB_USERPASS}  --site-mail=${ECOMM_EMAIL}  --site-name=${ECOMM_SITE_NAME}" 2>&1 | tee ${WORKDIR}/console_install.log

  echo -e "XXX\n100\nInstallation Complete!\nXXX"
  sleep 4
  } | whiptail --title "${SITE_TEMPLATE} Install" --gauge "Please wait while installing" 10 140 8

  {
  echo -e "XXX\n0\nSetting permissions on ${SITE_WEBROOT}/web\nXXX"
  log_exec sudo chown -R www-data:www-data ${SITE_WEBROOT}/web
  echo -e "XXX\n25\nSetting permissions on ${SITE_WEBROOT}/web... Done\nXXX"
  sleep 1
  echo -e "XXX\n25\nSetting permissions on ${SITE_WEBROOT}/web/files\nXXX"
  log_exec sudo chmod -R 775 ${SITE_WEBROOT}/web/files
  echo -e "XXX\n50\nSetting permissions on ${SITE_WEBROOT}/web/files... Done\nXXX"
  sleep 1
  echo -e "XXX\n50\nSetting permissions on ${SITE_WEBROOT}/drupal\nXXX"
  log_exec sudo chown -R www-data:www-data ${SITE_WEBROOT}/drupal
  echo -e "XXX\n75\nSetting permissions on ${SITE_WEBROOT}/drupal... Done\nXXX"
  sleep 1
  echo -e "XXX\n75\nSetting permissions on ${NGINX_ECOM_DOMAIN_P12}\nXXX"
  log_exec sudo chown www-data:www-data ${SITE_WEBROOT}/${NGINX_ECOM_DOMAIN_P12}
  echo -e "XXX\n100\nSetting permissions on ${NGINX_ECOM_DOMAIN_P12}... Done\nXXX"

  } | whiptail --title "${SITE_TEMPLATE} - Setting permissions" --gauge "Please wait while setting permissions" 10 140 8

  msgbox "$(cat ${WORKDIR}/console_install.log)"
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

setup_xdruple_nginx() {
  echo "Running: source ${SCRIPTS_DIR}/nginx-server.sh ${DEPLOYER_NAME} ${DOMAIN} ${DOMAIN_ALIAS} ${HTTP_AUTH_NAME} ${HTTP_AUTH_PASS} ${CONFIG_DIR}"
  source ${SCRIPTS_DIR}/nginx-server.sh ${DEPLOYER_NAME} ${DOMAIN} ${DOMAIN_ALIAS} ${HTTP_AUTH_NAME} ${HTTP_AUTH_PASS} ${CONFIG_DIR}
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
     Database: ${ERP_DATABASE_NAME}
     User: admin
     Pass: admin
    
 
     Web Client/REST:
     Login at: http://xtuple.xd:8888
     Login at: https:/${DOMAIN_ALIAS}:8443
     User: admin
     Pass: admin
 
     Ecommerce Site Login:
     Login at http://${DOMAIN_ALIAS}/login
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

install_composer() {
  git submodule update --init --recursive

  export SCRIPTS_DIR=$(pwd)/xdruple-server/scripts
  export CONFIG_DIR=$(pwd)/xdruple-server/config

  export TYPE='server'
  export DEPLOYER_NAME=`whoami`
  export TIMEZONE=America/New_York

  sudo timedatectl set-timezone ${TIMEZONE}

  source ${SCRIPTS_DIR}/php.sh ${TYPE} ${TIMEZONE} ${DEPLOYER_NAME} ${GITHUB_TOKEN} ${CONFIG_DIR}
}
