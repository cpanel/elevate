#!/bin/sh

RETVAL=1;
RETRIES=0;
SSH_KEY=$1;
HOST=$2;
# Default 30 RETRIES usually one second apart
RETRY_ARG=$3
MAX_RETRIES="${RETRY_ARG:=30}";

while [ $RETVAL -ne 0 ];
do
   # We want to exit immediately after we actually connect.
   ssh -i $SSH_KEY root@$HOST exit 0;
   RETVAL=$?;
   [ $RETVAL -eq 0 ] && echo "## [INFO] SUCCESS: Connected to ${HOST} ##" && exit 0;
   RETRIES=$((RETRIES+1));
   [ $RETVAL -ne 0 ] && echo "Retrying: Attempt ${RETRIES} ...";

   if [ ${RETRIES} -ge ${MAX_RETRIES} ];
   then
       echo "MAX_RETRIES has been reached.";
       exit 1;
   fi;
   sleep 5;
done
