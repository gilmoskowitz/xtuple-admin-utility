#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

sendglobalstos3()
{
  STARTRSJOB=$(date +%T)
  s3cmd put ${GLOBALOUT} ${S3BUCKET}/${GLOBALFILE}
  STOPRSJOB=$(date +%T)
  DBSIZE=$(ls -lh ${ARCHIVEDIR}/${BACKUPFILE} | cut -d' ' -f5)
}

