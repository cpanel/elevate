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
   ssh -i $SSH_KEY root@$HOST exit;
   RETVAL=$?;
   [ $RETVAL -eq 0 ] && echo Success;
   [ $RETVAL -ne 0 ] && echo Failure;
   RETRIES=$((RETRIES+1));
   echo "number of retries: $RETRIES";
   if [ ${RETRIES} -ge ${MAX_RETRIES} ];
   then
       echo "MAX_RETRIES has been reached.";
       exit 1;
   fi;
   sleep 5;
done
