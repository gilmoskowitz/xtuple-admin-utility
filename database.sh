#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

[ -n "$(typeset -F -p log)" ]                   || source ${BUILD_WORKING}/common.sh

database_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  log "Opened database menu"

  while true; do
    DBM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Database\ Menu )" 15 60 8 --cancel-button "Cancel" --ok-button "Select" \
            "1" "List Databases" \
            "2" "Inspect Database" \
            "3" "Rename Database" \
			"4" "Copy database" \
            "5" "Backup Database" \
			"6" "Create Database" \
            "7" "Drop Database" \
            "8" "Update/Web-enable Database" \
            "9" "Setup Automated Backup" \
            "10" "Return to main menu" \
            3>&1 1>&2 2>&3)

    RET=$?
    if [ $RET -ne 0 ]; then
      break
    else
      case "$DBM" in
        "1") log_exec list_databases ;;
        "2") inspect_database_menu ;;
        "3") rename_database ;;
	"4") copy_database ;;
        "5") log_exec backup_database ;;
	"6") create_database ;;
        "7") drop_database ;;
        "8") log_exec upgrade_database ;;
        "9") source xtnbackup2/xtnbackup.sh ;;
       "10") main_menu ;;
          *) msgbox "How did you get here?" && break ;;
      esac
    fi
  done
}

# auto, (no prompt for demo location, delete when done)
# manual, prompt for location, don't delete
download_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DEMODEST="$1"
  local DBVERSION="$2"
# $3 is type of database to grab (empty, demo, manufacturing, distribution, masterref)
# $4 is the database name to restore to

  if [ -z "$DBVERSION" ]; then
    msgbox "Database version not specified."
    return 1
  fi

  DBTYPE="${3:-$DBTYPE}"
  DBTYPE="${DBTYPE:-demo}"

  if [ -z "$DEMODEST" ] && [ "$MODE" = "manual" ]; then
    DEMODEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter the filename where you would like to save the database" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DEMODEST" ]; then
    return 127
  fi

  DB_URL="http://files.xtuple.org/$DBVERSION/$DBTYPE.backup"
  MD5_URL="http://files.xtuple.org/$DBVERSION/$DBTYPE.backup.md5sum"

  log "Saving "$DB_URL" as "$DEMODEST"."
  if [ $MODE = "auto" ]; then
    dlf_fast_console $DB_URL "$DEMODEST"
    dlf_fast_console $MD5_URL "$DEMODEST".md5sum
  else
    dlf_fast $DB_URL "Downloading Demo Database. Please Wait." "$DEMODEST"
    dlf_fast $MD5_URL "Downloading MD5SUM. Please Wait." "$DEMODEST".md5sum
  fi

  VALID=$(cat "$DEMODEST".md5sum | awk '{printf $1}')
  CURRENT=$(md5sum "$DEMODEST" | awk '{printf $1}')
  if [ "$VALID" != "$CURRENT" ]; then
    msgbox "There was an error verifying the downloaded database."
    return 1
  fi
}

# Copy a database: back it up with one name and restore with another
copy_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local OLDDATABASE="$1"
  local NEWDATABASE="$2"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 0
  fi

  if [ -z "$OLDDATABASE" ] && [ "$MODE" = "manual" ]; then
    OLDDATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to copy" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$OLDDATABASE" ]; then
    return 127
  fi

  if [ -z "$NEWDATABASE" ] && [ "$MODE" = "manual" ]; then
    NEWDATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$NEWDATABASE" ]; then
    return 127
  fi

  log "Copying database "$OLDDATABASE" to "$NEWDATABASE"."

  backup_database "$OLDDATABASE-copy.backup" "$OLDDATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Backup of $OLDDATABASE failed."
    return $RET
  fi

  restore_database "$BACKUPDIR/$OLDDATABASE-copy.backup" "$NEWDATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Restore of $NEWDATABASE failed."
    return $RET
  else
    msgbox "Database $OLDDATABASE successfully copied up to $NEWDATABASE"
    return 0
  fi
}

backup_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DEST=$1
  local DATABASE="$2"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  if [ -z "$DATABASE" ]; then
    get_database_list

    if [ -z "$DATABASES" ]; then
      msgbox "No databases detected on this system"
      return 0
    fi

    if [ "$MODE" = "auto" ]; then
      return 127
    fi
    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to back up" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  fi

  if [ -z "$DEST" ] && [ "$MODE" = "manual" ]; then
    DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save backup to" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DEST" ]; then
    return 127
  fi

  log "Backing up database "$DATABASE" to file "$DEST"."

  pg_dump --username "$PGUSER" --port "$PGPORT" --host "$PGHOST" --format custom  --file "$BACKUPDIR/$DEST" "$DATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Something has gone wrong. Check log and correct any issues."
    return $RET
  else
    msgbox "Database $DATABASE successfully backed up to $DEST"
    return 0
  fi
}

# Either download and restore a new database
# or restore a local file
# This can not be run in automatic mode
create_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "$MODE" = "auto" ] && return 127

  DOWNLOADABLEDBS=()
  while read -r line ; do
    DOWNLOADABLEDBS+=("$line" "$line")
  done < <( curl http://files.xtuple.org/ | grep -oP '/\d\.\d\d?\.\d/' | sed 's#/\(.*\)/#Download \1#g' |  sort --version-sort -r | tr ' ' '_' )
  EXISTINGDBS=()
  while read -r line ; do
    EXISTINGDBS+=("$line" "$line")
  done < <( ls -t "${DATABASEDIR}/*.backup" | tr ' ' '_' )
  BACKUPDBS=()
  while read -r line ; do
    BACKUPDBS+=("$line" "$line")
  done < <( ls -t $BACKUPDIR | awk '{printf("Restore %s\n", $0)}' | tr ' ' '_' )
  CUSTOMDB=("EnterFileName..." "EnterFileName...")

  CHOICE=$(whiptail --backtitle "$( window_title )" --menu "Choose Database" 15 60 7 --cancel-button "Cancel" --ok-button "Select" --notags \
        ${EXISTINGDBS[@]} \
        ${BACKUPDBS[@]} \
        ${CUSTOMDB[@]} \
        ${DOWNLOADABLEDBS[@]} \
        3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  echo $CHOICE | grep '^Download'
  if [ $? -eq 0 ]; then
    DBVERSION=$(echo $CHOICE | grep -oP '\d\.\d\d?\.\d')
    EDITIONS=()
    while read line ; do
      EDITIONS+=("$line" "$line")
    done < <( curl http://files.xtuple.org/$DBVERSION/ | grep -oP '>\K\S+.backup' | uniq )
    CHOICE=$(whiptail --backtitle "$( window_title )" --menu "Choose Database Edition" 15 60 7 --cancel-button "Cancel" --ok-button "Select" --notags \
      ${EDITIONS[@]} \
      3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    EDITION=$(echo $CHOICE | cut -f1 -d'.')
    download_database "$DATABASEDIR/$EDITION_$DBVERSION.backup" "$DBVERSION" "$EDITION"
    restore_database "$DATABASEDIR/$EDITION_$DBVERSION.backup"
    return $?
  fi

  echo $CHOICE | grep '^Backup db'
  if [ $? -eq 0 ]; then
    DATABASE=$(echo $CHOICE | sed 's/Backup db //')
    restore_database "$BACKUPDIR/$DATABASE"
    return $?
  fi

  if [ "$CHOICE" = "EnterFileName..." ]; then
    DATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "Full Database Pathname" 8 60 $(pwd) 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    restore_database "$DATABASE"
    return $?
  fi

  restore_database "$DATABASEDIR/$CHOICE"
  return $?
}

restore_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local BACKUPFILE="$1"
  local DATABASE="$2"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  if [ -z "$BACKUPFILE" ]; then
    msgbox "No filename provided."
    return 1
  fi

  if [ -z "$DATABASE" ] && [ "$MODE" = "manual" ]; then
    DATABASE=$(whiptail --backtitle "$( window_title )" --inputbox "New database name" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DATABASE" ]; then
    return 127
  fi

  log "Creating database $DATABASE."
  log_exec createdb -h $PGHOST -p $PGPORT -U $PGUSER -O "admin" "$DATABASE"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Something has gone wrong. Check log and correct any issues."
    return $RET
  else
    log "Restoring database $DATABASE from file $BACKUPFILE on server $PGHOST:$PGPORT"
    pg_restore --username "$PGUSER" --port "$PGPORT" --host "$PGHOST" --dbname "$DATABASE" "$BACKUPFILE" 2>restore_output.log
    RET=$?
    if [ $RET -ne 0 ]; then
      msgbox "$(cat restore_output.log)"
      return $RET
    else
      return 0
    fi
  fi
}

# list the existing databases on the current configured cluster
# this can not be run in automatic mode
list_databases() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "$MODE" = "auto" ] && return 127

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 0
  fi
  DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "List of databases on this cluster" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
}

# prompt if not provided
drop_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DATABASE="$1"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 0
  fi

  if [ -z "$DATABASE" ] && [ "$MODE" = "manual" ]; then
    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to drop" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi

    if (whiptail --title "Are you sure?" --yesno "Completely remove database $DATABASE?" 10 60) then
      backup_database "$BACKUPDIR/$DATABASE.$(date +%Y.%m.%d-%H:%M).backup" "$DATABASE"
      log_exec dropdb -U $PGUSER -h $PGHOST -p $PGPORT "$DATABASE"
      RET=$?
      if [ $RET -ne 0 ]; then
        msgbox "Dropping database $DATABASE failed. Please check the output and correct any issues."
        return $RET
      else
        msgbox "Dropping database $DATABASE successful"
      fi
    else
      return 0
    fi
  elif [ -z "$DATABASE" ]; then
    return 127
  fi
}

# prompt if not provided
rename_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local SOURCE="$1"
  local DEST="$2"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 0
  fi

  if [ -z "$SOURCE" ] && [ "$MODE" = "manual" ]; then
    SOURCE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to rename" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$SOURCE" ]; then
    return 127
  fi

  if [ -z "$DEST" ] && [ "$MODE" = "manual" ]; then
    DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Enter new name of database" 8 60 "" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return $RET
    fi
  elif [ -z "$DEST" ]; then
    return 127
  fi

  log_exec psql -qAt -U $PGUSER -h $PGHOST -p $PGPORT -d postgres -c "ALTER DATABASE $SOURCE RENAME TO $DEST;"
  RET=$?
  if [ $RET -ne 0 ]; then
    msgbox "Renaming database $SOURCE failed. Please check the output and correct any issues."
    return $RET
  else
    msgbox "Successfully renamed database $SOURCE to $DEST"
  fi
}

# display a menu of databases on the currently configured cluster
# can not be run in automatic mode
inspect_database_menu() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "MODE" = "auto"] && return 127

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 0
  fi

  DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to inspect" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return 0
  fi

  inspect_database "$DATABASE"
}

# Get a list of databases on the currently configured cluster
# into the DATABASES array
get_database_list() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  check_database_info

  DATABASES=()
  while read -r line; do
    DATABASES+=("$line" "$line")
  done < <( psql -At -U $PGUSER -h $PGHOST -p $PGPORT -d postgres -c "SELECT datname FROM pg_database WHERE datname NOT IN ('postgres', 'template0', 'template1');" )
}

## remove, kill, and restore are used to stop new connections
##   to a database in order to allow dropping
remove_connect_priv() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DB="$1"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  log_exec psql -At -U postgres -h $PGHOST -p $PGPORT -d postgres -c "REVOKE CONNECT ON DATABASE "$DB" FROM public, admin, xtrole;"
}

kill_database_connections() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DB="$1"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  log_exec psql -At -U postgres -h $PGHOST -p $PGPORT -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"$DB"';"
}

restore_connect_priv() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DB="$1"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  log_exec psql -At -U postgres -h $PGHOST -p $PGPORT -d postgres -c "GRANT CONNECT ON DATABASE "$DB" TO public, admin, xtrole;"
}

# Display important metrics of an xTuple database in the current configured cluster
inspect_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DB="$1"

  VAL=$(psql -At -U $PGUSER -h $PGHOST -p $PGPORT -d $DB -c "SELECT data FROM ( \
        SELECT 1,'Co: '||fetchmetrictext('remitto_name') AS data \
        UNION \
        SELECT 2,'Ap: '||fetchmetrictext('Application')||' v'||fetchmetrictext('ServerVersion') \
        UNION \
        SELECT 3,'Pk: '||pkghead_name||' v'||pkghead_version \
        FROM pkghead) as dummy ORDER BY 1;")

    msgbox "${VAL}"
}

# select a cluster that the functions in this file will use
# this can not be run in automatic mode, set the variables in script
set_database_info_select() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "$MODE" = "auto" ] && return 127

  CLUSTERS=()

  while read -r line; do 
    CLUSTERS+=("$line" "$line")
  done < <( sudo pg_lsclusters | tail -n +2 )

  if [ -z "$CLUSTERS" ]; then
    msgbox "No database clusters detected on this system. Entering setup."
    # Let's try to provision one.
    provision_cluster
    check_database_info
  fi

  CLUSTER=$(whiptail --title "xTuple Utility v$_REV" --menu "Select cluster to use" 16 120 5 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  if [ -z "$CLUSTER" ]; then
    msgbox "No database clusters detected on this system. Entering setup."
    provision_cluster
    check_database_info
  fi

  export PGVER=$(awk  '{print $1}' <<< "$CLUSTER")
  export POSTNAME=$(awk  '{print $2}' <<< "$CLUSTER")
  export PGPORT=$(awk  '{print $3}' <<< "$CLUSTER")
  export PGHOST=localhost
  export PGUSER=postgres

  PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Enter postgres user password" 8 60 3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  else
    export PGPASSWORD
  fi

  if [ -z "$PGVER" ] || [ -z "$POSTNAME" ] || [ -z "$PGPORT" ]; then
    msgbox "Could not determine database version or name"
    return 1
  fi
}

# set the current cluster by entering the parameters manually
# this can not be run in automatic mode
set_database_info_manual() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  [ "$MODE" = "auto" ] && return 127

  if [ -z "$PGHOST" ]; then
    PGHOST=$(whiptail --backtitle "$( window_title )" --inputbox "Hostname" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
      return $RET
    else
      export PGHOST
    fi
  fi
  if [ -z "$PGPORT" ] ; then
    PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Port" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
      return $RET
    else
      export PGPORT
    fi
  fi
  if [ -z "$PGUSER" ] ; then
    PGUSER=$(whiptail --backtitle "$( window_title )" --inputbox "Username" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
      return $RET
    else
      export PGUSER
    fi
  fi
  if [ -z "$PGPASSWORD" ] ; then
    PGPASSWORD=$(whiptail --backtitle "$( window_title )" --passwordbox "Password" 8 60 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      unset PGHOST && unset PGPORT && unset PGUSER && unset PGPASSWORD
      return $RET
    else
      export PGPASSWORD
    fi
  fi
}

clear_database_info() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  unset PGHOST
  unset PGPASSWORD
  unset PGPORT
  unset PGUSER
}

# Check that there is a currently selected cluster
check_database_info() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"

  if [ -z "$PGHOST" ] || [ -z "$PGPORT" ] || [ -z "$PGUSER" ]; then
    if (whiptail --yes-button "Select Cluster" --no-button "Manually Enter"  --yesno "Would you like to choose from installed clusters, or manually enter server information?" 10 60) then
      set_database_info_select
      RET=$?
      return $RET
    else
      # I specifically need to check for ESC here as I am using the yesno box as a multiple choice question, 
      # so it chooses no code even during escape which in this case I want to actually escape when someone hits escape. 
      if [ $? -eq 255 ]; then
        return 255
      fi
      set_database_info_manual
      RET=$?
      return $RET
    fi
  else
    return 0
  fi
}

# Upgrade an existing database to a Web-Enabled
upgrade_database() {
  echo "In: ${BASH_SOURCE} ${FUNCNAME[0]}"
  local DATABASE="$1"

  check_database_info
  RET=$?
  if [ $RET -ne 0 ]; then
    return $RET
  fi

  get_database_list

  if [ -z "$DATABASES" ]; then
    msgbox "No databases detected on this system"
    return 0
  fi

  if [ -z "$DATABASE" ] && [ "$MODE" = "manual" ]; then
    DATABASE=$(whiptail --title "PostgreSQL Databases" --menu "Select database to upgrade" 16 60 5 "${DATABASES[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
      return 0
    fi
  elif [ -z "$DATABASE" ]; then
    return 127
  fi

  psql -At -U $PGUSER -h $PGHOST -p $PGPORT -d $DATABASE -c "SELECT pkghead_name FROM pkghead WHERE pkghead_name='xt';"
  if [ $? -ne 0 ]; then
    if ! (whiptail --title "Database not Web-Enabled" --yesno "The selected database is not currently web-enabled. If you continue, this process will update AND web-enable the database. If you prefer to not web-enable the database, exit xTuple Admin Utility and use the xTuple Updater app to apply the desired update package. Continue?" 10 60) then
      return 0
    fi
  else
    return 127
  fi

  # make sure plv8 is in
  log_exec psql -At -U ${PGUSER} -p ${PGPORT} -d $DATABASE -c "create EXTENSION IF NOT EXISTS plv8;"

  # find the instance name and version
  CONFIG_JS=$(find /etc/xtuple -name 'config.js' -exec grep -Pl "(?<=databases: \[\")$DATABASE" {} \; -exec grep -P "(?<=port: \[\")$PGPORT" {} \;)
  if [ -z "$CONFIG_JS" ]; then
    # no installation exists, just skip to installation
    log "config.js not found. Skipping cleanup of old datasource."
    configure_nginx
  else
    MWCNAME=$(echo $CONFIG_JS | cut -d'/' -f5)
    MWCVERSION=$(echo $CONFIG_JS | cut -d'/' -f4)

    # shutdown node datasource
    if [ $DISTRO = "ubuntu" ]; then
      case "$CODENAME" in
        "trusty") ;&
        "utopic")
          log_exec sudo service xtuple-"$MWCNAME" stop
          ;;
        "vivid") ;&
        "xenial")
          log_exec sudo systemctl stop xtuple-"$MWCNAME".service
          log_exec sudo systemctl disable xtuple-"$MWCNAME".service
          ;;
      esac
    elif [ $DISTRO = "debian" ]; then
      case "$CODENAME" in
        "wheezy")
          log_exec sudo /etc/init.d/xtuple-"$MWCNAME" stop
          ;;
        "jessie")
          log_exec sudo systemctl stop xtuple-"$MWCNAME".service
          log_exec sudo systemctl disable xtuple-"$MWCNAME".service
          ;;
      esac
    else
      log "Seriously? We made it all the way to where we need to start the server and suddenly I can't detect your distro -> $DISTRO codename -> $CODENAME"
      do_exit
    fi

    # get the listening port for the node datasource
    MWCPORT=$(grep -Po '(?<= port: )8[0-9]{3}' /etc/xtuple/$MWCVERSION/$MWCNAME/config.js)
    if [ -z "$MWCPORT" ] && [ "$MODE" = "manual" ]; then
      MWCPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Web Client Port Number" 8 60 3>&1 1>&2 2>&3)
    elif [ -z "$MWCPORT" ]; then
      return 127
    fi
    NGINX_PORT=$MWCPORT
    
    log "Removing files in /etc/xtuple"
    log_exec sudo rm -rf /etc/xtuple/$MWCVERSION/$MWCNAME

    log "Removing files in /opt/xtuple"
    log_exec sudo rm -rf /opt/xtuple/$MWCVERSION/$MWCNAME

    log "Deleting systemd service file"
    log_exec sudo rm /etc/systemd/system/xtuple-$MWCNAME.service

    log "Completely removed previous mobile client installation"
  fi

  # install or update the web client
  ERP_DATABASE_NAME=$DATABASE
  install_mwc_menu

  # display results
  NEWVER=$(psql -At -U ${PGUSER} -p ${PGPORT} -d $DATABASE -c "SELECT fetchmetrictext('ServerVersion') AS application;")
  msgbox "Database $DATABASE\nVersion $NEWVER"
}
