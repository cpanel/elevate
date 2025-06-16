#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use lib '/usr/local/cpanel/';

use Cpanel::LoadFile ();
use Cpanel::OS       ();

use Test::More;

is( Cpanel::OS->distro(), 'almalinux', 'System is AlmaLinux after upgrade.' );
is( Cpanel::OS->major(),  '8',         'Verson 8 of OS.' );

# RE-1568
my $cpupdate = Cpanel::LoadFile::loadfile('/etc/cpupdate.conf');
my %contents = map { my ( $key, $value ) = split( "=", $_ ); $key => $value } split /\n/, $cpupdate;
is( $contents{CPANEL}, 'release', 'The cPanel update tier was updated to RELEASE' ) or diag explain \%contents;

done_testing();
