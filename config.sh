# Actions to take when the utility is run
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.
ACTIONS=()

# default configurations
LOG_FILE=$(pwd)/install-$DATE.log

DATABASEDIR=$(pwd)/databases
BACKUPDIR=$(pwd)/backups

# leave these undefined. They should never be used in this utility because it would lead to hard to pinpoint easy to fix bugs that cause a disproportionate amount of wasted time.
PGNAME=
PGPORT=

# set these
PGVER=9.6
PGHOST=localhost

# postgres user, required for all postgres/database actions
PGUSER=postgres

# usually set to $LANG
POSTLOCALE=$LANG

# default nginx site to select
NGINX_SITE=
# auto populated if site exists, otherwise can be used to create a site
NGINX_DOMAIN=
NGINX_HOSTNAME=
NGINX_PORT=
NGINX_CERT=
NGINX_KEY=
# generate new certs if the specified ones don't exist
GEN_SSL=false

# default mobile web instance to use
MWCNAME=
# version tag
MWCVERSION=
# switch for private extensions to be installed
PRIVATEEXT=
# optional, but will prompt if missing
GITHUBNAME=
GITHUBPASS=

# Variables for xdruple-server
if [[ ! -d $(pwd)/xdruple-server ]]; then
git submodule update --init --recursive
fi

if [[ -d $(pwd)/xdruple-server ]]; then
export SCRIPTS_DIR=$(pwd)/xdruple-server/scripts
export CONFIG_DIR=$(pwd)/xdruple-server/config
fi

export TYPE='server'
export DEPLOYER_NAME=$(whoami)
export TIMEZONE=$(</etc/timezone)

# get rid of these
# WORKDIR
# XTDIR
# XTVERSION
# INSTANCE
# DEMODEST
# DEST
# SOURCE
