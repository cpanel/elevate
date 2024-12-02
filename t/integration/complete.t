#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib '/usr/local/cpanel/';

use Cpanel::OS              ();
use Cpanel::SafeRun::Simple ();

use Test::More tests => 7;

use Data::Dumper;

is( Cpanel::OS->distro(),             'almalinux', 'System is Almalinux after upgrade.' );
is( Cpanel::OS->major(),              '8',         'Verson 8 of OS.' );
is( -e '/var/log/elevate-cpanel.log', 1,           'Elevate log exists.' );
like( Cpanel::SafeRun::Simple::saferun( '/bin/sh', '-c', '/scripts/restartsrv_httpd --status' ),  qr/is running as root/,  'Apache is up and accepting connections.' );
like( Cpanel::SafeRun::Simple::saferun( '/bin/sh', '-c', '/scripts/restartsrv_cpsrvd --status' ), qr/is running as root/,  'Chksrvd is up and accepting connections.' );
like( Cpanel::SafeRun::Simple::saferun( '/bin/sh', '-c', '/scripts/restartsrv_named --status' ),  qr/is running as named/, 'Nameserver is up and accepting connections.' );
ok( Cpanel::SafeRun::Simple::saferun( '/bin/sh', '-c', 'pgrep elevate' ) eq '', 'No instance of elevate-cpanel currently running.' );
