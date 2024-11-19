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

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

my %os_designation = (
    cent   => 0,
    cloud  => 0,
    ubuntu => 1,
);

foreach my $os ( sort keys %os_designation ) {
    set_os_to($os);
    is( Elevate::OS::is_experimental(), $os_designation{$os}, "OS has the expected experimental designation" );
}

done_testing();
