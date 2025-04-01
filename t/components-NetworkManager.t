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

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $nm = cpev->new->get_component('NetworkManager');

{
    note "checking pre_distro_upgrade";

    my $mock_systemctl = Test::MockModule->new('Elevate::SystemctlService');
    $mock_systemctl->redefine(
        is_enabled => sub { die "do not call this yet\n"; },
    );

    my $mock_nm = Test::MockModule->new('Elevate::Components::NetworkManager');
    $mock_nm->redefine(
        upgrade_distro_manually => 1,
    );

    is( $nm->pre_distro_upgrade(), undef, 'Returns early when upgrade manually option is passed' );

    $mock_nm->redefine(
        upgrade_distro_manually => 0,
    );

    my %os_hash = (
        alma   => [8],
        cent   => [7],
        cloud  => [ 7, 8 ],
        ubuntu => [20],
    );
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            next if $version == 8;
            set_os_to( $distro, $version );

            is( $nm->pre_distro_upgrade(), undef, 'Returns early when network manager does not need to be enabled prior to the distro upgrade' );
        }
    }

    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            next unless $version == 8;
            set_os_to( $distro, $version );

            my $called_enabled = 0;
            $mock_systemctl->redefine(
                is_enabled => 1,
                enable     => sub { $called_enabled++; },
            );

            is( $nm->pre_distro_upgrade(), undef, 'Return undef when the network manager service is already enabled' );
            is( $called_enabled,           0,     'Does not attempt to enable network manager if the service is already enabled' );

            $mock_systemctl->redefine(
                is_enabled => 0,
            );

            is( $nm->pre_distro_upgrade(), undef, 'Return undef when it enables the network manager service' );
            is( $called_enabled,           1,     'Enables the network manager service if it is not already enabled' );
        }
    }
}

done_testing();
