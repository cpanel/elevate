#!/bin/sh

set -x

wget -O /scripts/elevate-cpanel https://raw.githubusercontent.com/cpanel/elevate/release/elevate-cpanel
chmod -v 700 /scripts/elevate-cpanel
/scripts/elevate-cpanel --check
/usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.6
sleep 120
perl -pi*.bak -e 's/^CPANEL=.*/CPANEL=11.110/g' /etc/cpupdate.conf
/scripts/upcp
sleep 30
yes | /scripts/elevate-cpanel --start
/scripts/elevate-cpanel --log