#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

LOG_FILE=$(pwd)/install-$DATE.log

log_exec() {
   "$@" | tee -a $LOG_FILE 2>&1
   RET=${PIPESTATUS[0]}
   return $RET
}

log() {
    echo "$( timestamp ) xtuple >> $@"
    echo "$( timestamp ) xtuple >> $@" >> $LOG_FILE
}

timestamp() {
  date +"%T"
}

datetime() {
  date +"%D %T"
}

log "Logging initialized. Current session will be logged to $LOG_FILE"
