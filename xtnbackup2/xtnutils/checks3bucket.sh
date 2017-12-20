#!/bin/bash
# Copyright (c) 1999-2017 by OpenMFG LLC, d/b/a xTuple.
# See www.xtuple.com/CPAL for the full text of the software license.

checks3bucket()
{
  s3cmd mb ${S3BUCKET}
  sleep 10
}

