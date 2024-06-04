#!/bin/sh

RETVAL=1;
RETRIES=0;
HOST=$1;
PORT=$2
PORT="${PORT:=22}";
# Default 30 RETRIES usually one second apart
RETRY=$3
RETRY="${RETRY:=30}";

while [ $RETVAL -ne 0 ];
do
   # We want to exit immediately after we actually connect to SSH on default port.
   nc -z ${HOST} ${PORT}
   RETVAL=$?;
   [ $RETVAL -eq 0 ] && echo "## [INFO] SUCCESS: Connected to SSH on ${HOST} ##" && exit 0;
   RETRIES=$((RETRIES+1));
   [ $RETVAL -ne 0 ] && echo "## [DEBUG]: Retrying SSH Connect: Attempt ${RETRIES} ...";

   if [ ${RETRIES} -ge ${RETRY} ];
   then
       echo "## [ERROR]: ssh_retry.sh: MAX_RETRIES has been reached.";
       exit 1;
   fi;
   sleep 5;
done
