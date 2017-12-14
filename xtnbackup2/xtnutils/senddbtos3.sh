#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

senddbtos3()
{
  STARTRSJOB=$(date +%T)
  s3cmd put ${BACKUPOUT} ${S3BUCKET}/${BACKUPFILE}
  STOPRSJOB=$(date +%T)
  DBSIZE=$(ls -lh ${ARCHIVEDIR}/${BACKUPFILE} | cut -d' ' -f5)

  cat << EOF >> ${LOGFILE}
s3Link: ${S3BUCKET}/${BACKUPFILE}
Time: ${STARTRSJOB} / ${STOPRSJOB}
BackupSize: ${DBSIZE}
EOF

}

