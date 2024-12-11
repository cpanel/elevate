#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;
use Test2::Tools::Mock;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_cpev                 = Test::MockModule->new('cpev');
my $mock_cpanel_kernel_status = Test::MockModule->new('Cpanel::Kernel::Status');

my $comp = cpev->new->get_component('BootKernel');

{
    note 'Test blocker when --upgrade-distro-manually is passed';

    $mock_cpanel_kernel_status->redefine(
        reboot_status => sub { die "should not be called here\n"; },
    );

    $mock_cpev->redefine( upgrade_distro_manually => 1 );
    is( $comp->check(), 1, 'Should skip when upgrade-distro-manually is passed' );
}

{
    note 'Test BootKernel behavior';

    $mock_cpev->redefine( upgrade_distro_manually => 0 );

    my $rv;
    my $bv;
    $mock_cpanel_kernel_status->redefine(
        reboot_status => sub {
            return {
                running_version => $rv,
                boot_version    => $bv,
            };
        },
    );

    $rv = 42;
    $bv = 42;
    is( $comp->check(), 1, 'No blocker when running version matches boot version' );

    $rv = 13;
    is( $comp->check(), 0, 'Blocker returned when running version does not match boot version' );

    $mock_cpanel_kernel_status->redefine(
        reboot_status => sub { die "fail to do the thing\n" },
    );

    is( $comp->check(), 0, 'Blocker returned when we fail to determine the running kernel version' );
}

done_testing();
