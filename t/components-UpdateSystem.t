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
use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_cpanel_exclude_packages = Test::MockFile->file( '/etc/apt/preferences.d/99-cpanel-exclude-packages', '' );

my $mock_pkgmgr = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
my $mock_comp   = Test::MockModule->new('Elevate::Components::UpdateSystem');

my $comp = cpev->new->get_component('UpdateSystem');

{
    note 'pre_distro_upgrade';

    my $called_clean_all;
    my $called_update;
    $mock_pkgmgr->redefine(
        clean_all => sub { $called_clean_all++; },
        update    => sub { $called_update++; },
    );

    my @ssystem_and_die_params;
    $mock_comp->redefine(
        ssystem_and_die => sub {
            shift;
            @ssystem_and_die_params = @_;
            return;
        },
    );

    foreach my $os ( 'cent', 'cloud', 'ubuntu' ) {
        $called_clean_all = 0;
        $called_update    = 0;

        is( $comp->pre_distro_upgrade(), undef, 'Returns undef' );
        is( $called_clean_all,           1,     'pre_distro_upgrade called clean all' );
        is( $called_update,              1,     'pre_distro_upgrade called update' );
        is(
            \@ssystem_and_die_params,
            [
                '/scripts/update-packages',
            ],
            'Expected script was called'
        );
    }
}

done_testing();
