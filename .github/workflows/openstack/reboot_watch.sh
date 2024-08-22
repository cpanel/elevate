#!/bin/bash

while [ $RETVAL -ne 0 ]; do
	grep "${REGEX}" /var/log/elevate-cpanel.log;
	RETVAL=$?; 
	[ $RETVAL -eq 0 ] && echo "## [INFO] SUCCESS: Reboot text found in /var/log/elevate-cpanel.log  ##" && exit 0;
	RETRIES=$((RETRIES+1));
	[ $RETVAL -ne 0 ] && echo "## [DEBUG]: Retrying Reboot REGEX Search: Attempt ${RETRIES} ...";
	sleep 1;
done
