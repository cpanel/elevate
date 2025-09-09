#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::experimental_os;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;
use Test2::Tools::Mock;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/../lib";
use Elevate::OS ();

use lib $FindBin::Bin . "/lib";
use Test::Elevate::OS ();

my %os_designation = (
    AlmaLinux8  => 0,
    CentOS7     => 0,
    CloudLinux7 => 0,
    CloudLinux8 => 0,
    Ubuntu20    => 0,
);

foreach my $os ( Elevate::OS::SUPPORTED_DISTROS() ) {
    my ( $distro, $major ) = split ' ', $os;

    my $as_distro = lc "set_os_to_${distro}_${major}";
    Test::Elevate::OS->can($as_distro)->();

    is( Elevate::OS::is_experimental(), $os_designation{"$distro$major"}, "OS has the expected experimental designation" );
}

done_testing();
