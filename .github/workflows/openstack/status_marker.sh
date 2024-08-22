#!/bin/sh

STAGE=$1;
RELEASE_INFO=$(cat /etc/redhat-release);
CPANEL_VERSION=$(cat /usr/local/cpanel/version);

RC=$(echo ${RELEASE_INFO} | wc -c)



for ((i=1; i<=${RC}+17; i++)); do echo -n "#"; done
echo;
echo "# STAGE: ${STAGE} of 5                                           #";
echo "# OS Release: ${RELEASE_INFO}   #";
echo "# cP Version: ${CPANEL_VERSION}                               #";
for ((i=1; i<=${RC}+17; i++)); do echo -n "#"; done
echo;
