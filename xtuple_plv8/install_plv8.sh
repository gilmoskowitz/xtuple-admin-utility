#!/bin/bash

PROG=$(basename $0)
OS=$(uname -s)
ECHO=""

function usage() {
  echo "$PROG -h"
  echo "$PROG [ -n ] [ -x ] [ /PostgreSQL/install/dir ]"
  echo "  -n      show what $0 _would_ do but don't actually do it"
  echo "  -x      turn on debugging output"
}

while getopts hnx OPT ; do
  case $OPT in
    h) usage
       exit 0
       ;;
    n) ECHO="echo "
       ;;
    x) set -x
       ;;
  esac
done
shift $(($OPTIND - 1))

if [ $# -ge 1 ] ; then
  DEF_PGDIR="$1"
  [ $# -eq 1 ] || echo "$0: ignoring extra arguments"
elif [ -n "$PGDIR" ] ; then
  DEF_PGDIR="$PGDIR"
else
  DEF_PGDIR=$(command -v psql | xargs dirname | xargs dirname)
  if [ "$DEF_PGDIR" = / ] ; then
    DEF_PGDIR=""
  fi
fi

DONE=false
while ! $DONE ; do
  read -p "Where is PostgreSQL installed? [$DEF_PGDIR] " PGDIR
  if [ -z "$PGDIR" ] ; then
    PGDIR="$DEF_PGDIR"
  fi
  if [ ! -d "$PGDIR" ] ; then
    echo "$PGDIR" is not a directory
  elif [ ! -d "$PGDIR/lib" -a ! -x "$PGDIR/bin/psql" ] ; then
    echo "$PGDIR does not look like a PostgreSQL installation directory"
  else
    DONE=true
  fi
done

if [ ! -w "$PGDIR" -o ! -w "$PGDIR/lib" ] ; then
  echo "Please run as a user with permissions to write to $PGDIR"
  exit 1
fi

PATH="$PGDIR/bin:$PATH"
PGVER=$(expr $(pg_config --version | cut -f2 -d" " ) : "\([0-9]*\.[0-9]*\).*")

PGLIBDIR=$(pg_config --libdir)
PKGLIBDIR=$(pg_config --pkglibdir)
EXTLIB=$(grep module_pathname plv8.control | cut -f2 -d"'" | sed -e "s,\$libdir,$PKGLIBDIR,")
EXTDIR=$(pg_config --sharedir)/extension

# Linux-only because build_plv8.sh on Mac creates dual-arch libraries
if [ "$OS" = Linux ] ; then
  PGFMT=$(file -Lb $PGLIBDIR/libpq.so | cut -f1 -d,)
  PLV8FMT=$(file -Lb plv8_${PGVER}*.so | cut -f1 -d,)
  if [ "$PGFMT" != "$PLV8FMT"  ] ; then
    echo "Expecting '$PGFMT' but plv8 was built as '$PLV8FMT'."
    echo "See https://github.com/xtuple/wiki/Installing-Plv8#linux-servers."
    exit 2
  fi
fi

$ECHO /usr/bin/install -d -m 755 $(dirname "$EXTLIB")
$ECHO /usr/bin/install -C -m 755 plv8_${PGVER}*.so "${EXTLIB}.so"
if [ "$OS" = Linux ] ; then     # it's unclear why some linux versions need this
  $ECHO /usr/bin/install -C -m 755 plv8_${PGVER}*.so "$PGLIBDIR/plv8.so"
fi

$ECHO /usr/bin/install -d -m 755 "${EXTDIR}"
$ECHO /usr/bin/install -C -m 644 *.control *.sql "${EXTDIR}"
