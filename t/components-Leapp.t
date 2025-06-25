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

my $mock_comp         = Test::MockModule->new('Elevate::Components::Leapp');
my $mock_elevate_comp = Test::MockModule->new('Elevate::Components');
my $mock_leapp        = Test::MockModule->new('Elevate::Leapp');

my $comp = cpev->new->get_component('Leapp');

{
    note 'Test blocker when --upgrade-distro-manually is passed';

    my %os_hash = (
        alma => [8],
        cent => [7],
    );
    foreach my $distro ( keys %os_hash ) {
        next if $distro ne 'cent' && $distro ne 'alma';
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_elevate_comp->redefine(
                num_blockers_found => sub { "do not call\n"; },
            );

            $mock_comp->redefine(
                is_check_mode => 1,
            );

            is( $comp->check(), undef, 'Returns early if in check mode' );

            $mock_comp->redefine(
                is_check_mode => 0,
            );
        }
    }

    set_os_to( 'ubuntu', 20 );
    is( $comp->check(), undef, 'Returns early if the OS does not rely on leapp to upgrade' );

    foreach my $distro ( keys %os_hash ) {
        next if $distro ne 'cent' && $distro ne 'alma';
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_leapp->redefine(
                install => sub { die "Do not call\n"; },
            );

            $mock_elevate_comp->redefine(
                num_blockers_found => 1,
            );

            is( $comp->check(), undef, 'Returns early if there are existing blockers found' );

            my $num_blockers_found = 0;
            $mock_elevate_comp->redefine(
                num_blockers_found => sub { return $num_blockers_found; },
            );

            $mock_comp->redefine(
                _check_for_inhibitors   => sub { $num_blockers_found++; return; },
                _check_for_fatal_errors => 0,
            );

            my $preupgrade_out;
            $mock_leapp->redefine(
                install    => 1,
                preupgrade => sub { return $preupgrade_out; },
            );

            $preupgrade_out = {
                status => 0,
            };

            is( $comp->check(), undef, 'No blockers returns if leapp preupgrade returns clean' );
            no_messages_seen();

            $preupgrade_out = {
                status => 42,
            };

            is( $comp->check(), undef, 'Returns undef' );
            message_seen( INFO => qr/Leapp found issues which would prevent the upgrade/ );
            no_messages_seen();
        }
    }
}

done_testing();
