#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

s3chk()
{
  echo "Checking for AWS dependencies"
  S3CHK='s3cmd'

  for PART in $S3CHK; do
    if [ -z $(which $PART) ] ; then
      echo "Cannot find ${PART}! It might be ok."
    fi
  done

  echo "Looks good. Found: ${S3CHK}!"
  echo "Checking aws configs"
  if [ -f ~/.s3cfg ] ; then
    echo "Found s3cmd config: ~/.s3cfg"
  else
    echo "AWS s3cmd won't work! You should create ~/.s3cfg (Run s3cmd --configure ?)"
    PS3="Select an Option: "
    OPTS='yes no'
    select OPT in $OPTS ; do
      if [ $OPT = 'yes' ] ; then
        s3cmd  --configure
        break
      else
        echo "leaving"
        break 
     fi
   done
  fi
}
