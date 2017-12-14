#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

postgresql_menu() {

    log "Opened PostgreSQL menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title PostgreSQL\ Menu )" 0 0 9 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Install PostgreSQL $PGVER" \
            "2" "List provisioned clusters" \
            "3" "Select Cluster" \
            "4" "Create new cluster" \
            "5" "Backup Globals" \
            "6" "Restore Globals" \
            "7" "Return to main menu" \
            3>&1 1>&2 2>&3)

        RET=$?
        if [ $RET -ne 0 ]; then
            # instead of exiting, bring us back to the previous menu. Will capture escape and other cancels. 
            break
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") log_exec install_postgresql $PGVER ;;
            "2") log_exec list_clusters ;;
            "3") log_exec select_cluster ;;
            "4") log_exec provision_cluster ;;
            "5") log_exec backup_globals ;;
            "6") log_exec restore_globals ;;
            "7") break ;;
            *) msgbox "Error. How did you get here?" && break ;;
            esac
        fi
    done

}

password_menu() {

    log "Opened password menu"

    while true; do
        PGM=$(whiptail --backtitle "$( window_title )" --menu "$( menu_title Reset\ Password\ Menu )" 0 0 7 --cancel-button "Cancel" --ok-button "Select" \
            "1" "Reset postgres via sudo postgres" \
            "2" "Reset postgres via psql" \
            "3" "Reset admin via sudo postgres" \
            "4" "Reset admin via psql" \
            "5" "Return to previous menu" \
            3>&1 1>&2 2>&3)

        RET=$?

        if [ $RET -ne 0 ]; then
            break
        elif [ $RET -eq 0 ]; then
            case "$PGM" in
            "1") reset_sudo postgres ;;
            "2") reset_psql postgres ;;
            "3") reset_sudo admin ;;
            "4") reset_psql admin ;;
            "5") break ;;
            *) msgbox "How did you get here?" && exit 0 ;;
            esac
        fi
    done

}


# $1 is pg version (9.3, 9.4, etc)
install_postgresql() {

    PGVER="${1:-$PGVER}"

# Let's not install the main cluster by default just to drop it...

    log_exec sudo apt-get -y install postgresql-common
    sudo sed -i -e s/'#create_main_cluster = true'/'create_main_cluster = false'/g /etc/postgresql-common/createcluster.conf

    log_exec sudo apt-get -y install postgresql-$PGVER postgresql-client-$PGVER postgresql-contrib-$PGVER postgresql-$PGVER-plv8 postgresql-server-dev-$PGVER
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    elif [ $RET -eq 0 ]; then
        export PGUSER=postgres
        export PGPASSWORD=postgres
        export PGHOST=localhost
        export PGPORT=5432
        return $RET
    fi

    provision_cluster
}

# $1 is pg version (9.3, 9.4, etc)
# we don't remove -client because we still need it for managment tasks
remove_postgresql() {

    PGVER="${1:-$PGVER}"
    if (whiptail --title "Are you sure?" --yesno "Uninstall PostgreSQL $PGVER? Cluster data will be left behind." --yes-button "Yes" --no-button "No" 10 60) then
        log "Uninstalling PostgreSQL "$PGVER"..."
        log_exec sudo apt-get -y remove postgresql-$PGVER postgresql-contrib-$PGVER postgresql-$PGVER-plv8 postgresql-server-dev-$PGVER
        RET=$?
        return $RET
    else
        return 0
    fi

}

# $1 is pg version (9.3, 9.4, etc)
# we don't remove -client because we still need it for managment tasks
purge_postgresql() {

    PGVER="${1:-$PGVER}"
    if (whiptail --title "Are you sure?" --yesno "Completely remove PostgreSQL $PGVER and all of the cluster data?" --yes-button "Yes" --no-button "No" 10 60) then
        log "Purging PostgreSQL "$PGVER"..."
        log_exec sudo apt-get -y purge postgresql-$PGVER postgresql-contrib-$PGVER postgresql-$PGVER-plv8
        RET=$?
        return $RET
    else
        return 0
    fi

}

get_cluster_list() {

    CLUSTERS=()
    
    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( sudo pg_lsclusters | tail -n +2 )

}

list_clusters() {

    get_cluster_list

    if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    msgbox "$(sudo pg_lsclusters)"

}

# $1 is postgresql version
# $2 is cluster name
# $3 is port
# $4 is locale
# $5 if exists, start at boot
provision_cluster() {

    PGVER="${1:-$PGVER}"
    if [ -z "$PGVER" ] && [ "$MODE" = "manual" ]; then
        PGVER=$(whiptail --backtitle "$( window_title )" --inputbox "Enter PostgreSQL Version (make sure it is installed!)" 8 60 "$PGVER" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return 0
        fi
    fi

    POSTNAME="$2"
    if [ -z "$POSTNAME" ] && [ "$MODE" = "manual" ]; then
        POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Cluster Name\n\nExisting Clusters:\n$(sudo pg_lsclusters -h | awk '{print $2}')" 15 60 "xtuple" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return 0
        fi
    fi

    PGPORT="$3"
    if [ -z "$PGPORT" ] && [ "$MODE" = "manual" ]; then
        # choose a free port automatically someday
        new_postgres_port
        PGPORT=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Database Port" 8 60 "$PGPORT" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return 0
        fi
    fi

    POSTLOCALE="${4:-$POSTLOCALE}"
    if [ -z "$POSTLOCALE" ] && [ "$MODE" = "manual" ]; then
        POSTLOCALE=$(whiptail --backtitle "$( window_title )" --inputbox "Enter Locale" 8 60 "$LANG" 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return 0
        fi
    fi

    POSTSTART="${5:-$POSTSTART}"
    if [ -z "$POSTSTART" ] && [ "$MODE" = "manual" ]; then
        if (whiptail --title "Autostart" --yes-button "Yes" --no-button "No"  --yesno "Would you like the cluster to start at boot?" 10 60) then
            POSTSTART="--start-conf=auto"
        else
            POSTSTART=""
        fi
    fi

    sudo pg_lsclusters -h | awk '{print $2}' | grep $POSTNAME 2>&1 > /dev/null
    if [ "$?" -eq 0 ]; then
        log "Cluster $POSTNAME already exists."
        return 2
    fi

    sudo pg_lsclusters -h | awk '{print $3}' | grep $PGPORT 2>&1 > /dev/null
    if [ "$?" -eq 0 ]; then
        msgbox "Port $PGPORT is already in use."
        return 1
    fi

    log "Creating database cluster $POSTNAME using version $PGVER on port $PGPORT encoded with $POSTLOCALE"
### PERRY
    log_exec sudo bash -c "su - root -c \"pg_createcluster --locale $POSTLOCALE -p $PGPORT --start $POSTSTART $PGVER $POSTNAME -o listen_addresses='*' -o log_line_prefix='%t %d %u ' -- --auth=trust --auth-host=trust --auth-local=trust\""
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Creation of PostgreSQL cluster failed. Please check the output and correct any issues."
        do_exit
    fi

    POSTDIR=/etc/postgresql/$PGVER/$POSTNAME

    log "Opening pg_hba.conf for internet access with passwords"
    log_exec sudo bash -c "echo  \"host    all             all             0.0.0.0/0                 md5\" >> $POSTDIR/pg_hba.conf"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Opening pg_hba.conf for internet access failed. Check log file and try again. "
        do_exit
    fi

    log "Adding plv8.start_proc='xt.js_init' to postgresql.conf"
    log_exec sudo bash -c "echo  \"plv8.start_proc='xt.js_init'\" >> $POSTDIR/postgresql.conf"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Adding plv8.start_proc to postgresql.conf failed. Check the log file for any issues.\nSee https://github.com/xtuple/xtuple/wiki/Installing-PLv8 for more information."
        do_exit
    fi

    log "Restarting PostgreSQL $PGVER for $POSTNAME"
    # you may wonder why I have this block when the commands are all the same, the reason is that
    # we only support ubuntu derivatives currently, but in the near future that will not be the
    # case, and I will lose access to pg_ctlcluster and its friends.
    if [ $DISTRO = "ubuntu" ]; then
        case "$CODENAME" in
            "trusty")
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" stop --force
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" start
                ;;
            "utopic")
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" stop --force
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" start
                ;;
            "vivid") ;&
            "xenial")
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" stop --force
                log_exec sudo systemctl enable postgresql@$PGVER-"$POSTNAME"
                log_exec sudo systemctl start postgresql@$PGVER-"$POSTNAME"
                ;;
        esac
    elif [ $DISTRO = "debian" ]; then
        case "$CODENAME" in
            "wheezy")
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" restart
                ;;
            "jessie")
                log_exec sudo pg_ctlcluster $PGVER "$POSTNAME" stop
                log_exec sudo systemctl enable postgresql@$PGVER-"$POSTNAME"
                log_exec sudo systemctl start postgresql@$PGVER-"$POSTNAME"
                ;;
        esac
    fi

    export PGHOST=localhost
    export PGUSER=postgres
    export PGPASSWORD=postgres

    if [ $MODE = "manual" ]; then
        msgbox "Creation of database cluster $POSTNAME using version $PGVER was successful. You will now be asked to set a postgresql password"
        reset_sudo postgres
        if [ $RET -ne 0 ]; then
            msgbox "Error setting the postgres password. Correct any errors on the console. \nYou can try setting the password via another method using the Password Reset menu."
            do_exit
        fi
    else
        log "Creation of database cluster $POSTNAME using version $PGVER was successful."
    fi

    INIT_URL="http://files.xtuple.org/common/init.sql"

    if [ $MODE = "auto" ]; then
        dlf_fast_console $INIT_URL $WORKDIR/init.sql
        dlf_fast_console $INIT_URL.md5sum $WORKDIR/init.sql.md5sum
    else
        dlf_fast $INIT_URL "Downloading init.sql. Please Wait." $WORKDIR/init.sql
        dlf_fast $INIT_URL.md5sum "Downloading init.sql.md5sum. Please Wait." $WORKDIR/init.sql.md5sum
    fi

    VALID=$(cat $WORKDIR/init.sql.md5sum | awk '{printf $1}')
    CURRENT=$(md5sum $WORKDIR/init.sql | awk '{printf $1}')
    if [ "$VALID" != "$CURRENT" ] || [ -z "$VALID" ]; then
        msgbox "There was an error verifying the init.sql that was downloaded. Utility will now exit."
        do_exit
    fi

    log "Deploying init.sql, creating admin user and xtrole group"
    psql -q -h $PGHOST -U postgres -d postgres -p $PGPORT -f $WORKDIR/init.sql
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Error deploying init.sql. Check for errors and try again"
        do_exit
    fi

    log "Removing downloaded init scripts..."
    rm $WORKDIR/init.sql{,.md5sum}

    msgbox "Initializing cluster successful."

    return 0

}

select_cluster() {

    set_database_info_select

}

# $1 is version
# $2 is name
# $3 is mode (auto/manual)
# prompt if not provided
drop_cluster() {

    PGVER="${1:-$PGVER}"
    POSTAME="${2:-$POSTNAME}"
    MODE="${3:-$MODE}"
    MODE="${MODE:-manual}"

    if [ $MODE = "manual" ]; then
        if [ -z "$PGVER" ]; then
            PGVER=$(whiptail --backtitle "$( window_title )" --inputbox "Enter version of cluster to remove" 8 60 "" 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return 0
            fi
        fi

        if [ -z "$POSTNAME" ]; then
            POSTNAME=$(whiptail --backtitle "$( window_title )" --inputbox "Enter name of cluster to remove" 8 60 "" 3>&1 1>&2 2>&3)
            RET=$?
            if [ $RET -ne 0 ]; then
                return 0
            fi
        fi

        if (whiptail --title "Are you sure?" --yesno "Completely remove cluster $POSTNAME - $PGVER?" --yes-button "No" --no-button "Yes" 10 60) then
            return 0
        fi
    fi

    log "Dropping PostgreSQL cluster $POSTNAME version $PGVER"

   # We do not want to drop ANY CLUSTERS.  Either modify what is there for plv8/pg_hba.conf or CREATE new.
  # log_exec sudo su - postgres -c "pg_dropcluster --stop $PGVER $POSTNAME"
true
    RET=$?
    if [ $MODE = "manual" ]; then
        if [ $RET -ne 0 ]; then
            msgbox "Dropping PostgreSQL cluster failed. Please check the output and correct any issues."
            do_exit
        else
            msgbox "Dropping PostgreSQL cluster $POSTNAME version $PGVER completed successfully."
        fi
    fi
    return $RET
}

drop_cluster_menu() {

    CLUSTERS=()

    while read -r line; do 
        CLUSTERS+=("$line" "$line")
    done < <( sudo pg_lsclusters | tail -n +2 )

     if [ -z "$CLUSTERS" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    CLUSTER=$(whiptail --title "PostgreSQL Clusters" --menu "Select cluster to drop" 16 120 5 "${CLUSTERS[@]}" --notags 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    if [ -z "$CLUSTER" ]; then
        msgbox "No database clusters detected on this system"
        return 0
    fi

    VER=$(awk  '{print $1}' <<< "$CLUSTER")
    NAME=$(awk  '{print $2}' <<< "$CLUSTER")

    if [ -z "$VER" ] || [ -z "$NAME" ]; then
        msgbox "Could not determine database version or name"
        return 0
    fi

    log_exec drop_cluster "$VER" "$NAME"

}

# $1 is user to reset
reset_sudo() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    NEWPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "New $1 password" 8 60  3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    log "Resetting PostgreSQL password for user $1 using psql via su - postgres"

    log_exec psql -qAt -U $PGUSER -h $PGHOST -p $PGPORT -d postgres -c "ALTER USER $1 WITH PASSWORD '$NEWPASS';"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Looks like something went wrong resetting the password via sudo. Try using psql, or opening up pg_hba.conf"
        return 0
    else
        export PGUSER=$1
        export PGPASSWORD=$NEWPASS
        msgbox "Password for user $1 successfully reset"
        return 0
    fi

}

# $1 is user to reset
reset_psql() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    NEWPASS=$(whiptail --backtitle "$( window_title )" --passwordbox "New $1 password" 8 60 "$CH" 3>&1 1>&2 2>&3)
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi
    
    log "Resetting PostgreSQL password for user $1 using psql directly"
    
    log_exec psql -q -h $PGHOST -U postgres -d postgres -p $PGPORT -c "ALTER USER $1 WITH PASSWORD '$NEWPASS';"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Looks like something went wrong resetting the password via psql. Try using sudo psql, or opening up pg_hba.conf"
        return 0
    else
        export PGUSER=$1
        export PGPASSWORD=$NEWPASS
        msgbox "Password for user $1 successfully reset"
        return 0
    fi
    
}

#  $1 is globals file to backup to
backup_globals() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return $RET
    fi

    if [ -z "$1" ]; then
        DEST=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to save globals to" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        DEST=$1
    fi
    
    log "Backing up globals to file "$DEST"."

    log_exec pg_dumpall --host "$PGHOST" --port "$PGPORT" --username "$PGUSER" --database "postgres" --no-password --file "$DEST" --globals-only
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        msgbox "Globals successfully backed up to $DEST"
        return 0
    fi
}

#  $1 is globals file to restore
restore_globals() {

    check_database_info
    RET=$?
    if [ $RET -ne 0 ]; then
        return 0
    fi

    if [ -z "$1" ]; then
        SOURCE=$(whiptail --backtitle "$( window_title )" --inputbox "Full file name to globals file" 8 60 3>&1 1>&2 2>&3)
        RET=$?
        if [ $RET -ne 0 ]; then
            return $RET
        fi
    else
        SOURCE=$1
    fi

    log "Restoring globals from file $SOURCE"

    log_exec psql -h $PGHOST -p $PGPORT -U $PGUSER -d postgres -q -f "$SOURCE"
    RET=$?
    if [ $RET -ne 0 ]; then
        msgbox "Something has gone wrong. Check output and correct any issues."
        do_exit
    else
        msgbox "Globals successfully restored."
        return 0
    fi
}
