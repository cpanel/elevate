#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib '/usr/local/cpanel/';

use Cpanel::OS              ();
use Cpanel::SafeRun::Simple ();

use Test::More tests => 2;

use Data::Dumper;

is( Cpanel::OS->distro(), 'cloudlinux', 'System is Almalinux after upgrade.' );
is( Cpanel::OS->major(),  '8',          'Verson 8 of OS.' );

