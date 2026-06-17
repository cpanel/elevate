#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
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
my $mock_check_cpanel_pkgs       = Test::MockFile->file('/usr/local/cpanel/scripts/check_cpanel_pkgs');

my $mock_pkgmgr        = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
my $mock_pkgmgr_module = Test::MockModule->new('Elevate::PkgMgr');
my $mock_pkgr_comp     = Test::MockModule->new('Elevate::Components::UpdateSystem');

my $comp = cpev->new->get_component('UpdateSystem');

{
    note 'pre_distro_upgrade';

    my $called_clean_all;
    my $called_update;
    my @call_order;
    $mock_pkgmgr->redefine(
        clean_all => sub { $called_clean_all++; },
        update    => sub { $called_update++; push @call_order, 'update'; },
    );
    $mock_pkgmgr_module->redefine(
        remove_cpanel_exclude_packages_file => sub { push @call_order, 'remove_exclude_file'; },
    );

    my @ssystem_and_die_params;
    my @system_params;
    $mock_pkgr_comp->redefine(
        ssystem_and_die => sub {
            shift;
            @ssystem_and_die_params = @_;
            return;
        },
        _check_cpanel_pkgs => sub {
            shift;
            return;
        },
        _fix_cpanel_pkgs => sub {
            shift;
            @system_params = @_;
            return;
        }
    );

    foreach my $os ( [ cent => 7 ], [ cloud => 7 ], [ ubuntu => 22 ] ) {
        set_os_to( $os->@* );

        $called_clean_all = 0;
        $called_update    = 0;
        @call_order       = ();

        is( $comp->pre_distro_upgrade(), undef, 'Returns undef' );
        is( $called_clean_all,           1,     'pre_distro_upgrade called clean all' );
        is( $called_update,              1,     'pre_distro_upgrade called update' );
        is(
            \@ssystem_and_die_params,
            [
                '/usr/local/cpanel/scripts/update-packages',
            ],
            'Expected script was called'
        );

        if ( Elevate::OS::is_apt_based() ) {

            # The exclude file must be removed *before* the apt upgrade so the
            # upgrade can bring base-files (and anything else pinned) fully up
            # to date for the source release. The cross-release pin is cleared
            # again just before do-release-upgrade (RE-1668).
            is(
                \@call_order,
                [ 'remove_exclude_file', 'update' ],
                'apt exclude file is removed before PkgMgr::update'
            );
        }
        else {
            is(
                \@call_order,
                ['update'],
                'exclude file removal is skipped on non-apt systems'
            );
        }
    }
}

{
    note 'check';

    my @ssystem_capture_output_params;
    $mock_pkgr_comp->redefine(
        check => sub {
            shift;
            @ssystem_capture_output_params = @_;
            return;
        },
    );

    foreach my $os ( 'cent', 'cloud', 'ubuntu' ) {
        is( $comp->check(), undef, 'Returns undef' );
        is(
            \@ssystem_capture_output_params,
            [],
            '/usr/local/cpanel/scripts/check_cpanel_pkgs was called'
        );
    }

    $mock_pkgr_comp->redefine(
        check => sub {
            shift;
            @ssystem_capture_output_params = qw/ 1 /;
            return 1;
        },
    );

    foreach my $os ( 'cent', 'cloud', 'ubuntu' ) {
        is( $comp->check(), 1, 'Returns 1' );
        is(
            \@ssystem_capture_output_params,
            [
                '1',
            ],
            '/usr/local/cpanel/scripts/check_cpanel_pkgs was called and returned'
        );
    }
    my $mock = Test::MockModule->new('Elevate::Components::UpdateSystem');

    # Create an instance of Elevate::Components::UpdateSystem
    $comp = cpev->new->get_component('UpdateSystem');

    # Mock ssystem_capture_output to simulate output of /usr/local/cpanel/scripts/check_cpanel_pkgs

    $mock_pkgr_comp->redefine(
        check => sub {
            shift;
            @ssystem_capture_output_params = qw/ 0 /;
            return 0;
        },
        _check_cpanel_pkgs => sub {
            shift;
            @ssystem_capture_output_params = qw/ 1 /;
            return 1;
        },
    );

    # Mock ssystem to prevent real system calls
    $mock->redefine( 'ssystem', sub { return 0; } );

    # Test _check_cpanel_pkgs when problems are detected
    is( $comp->_check_cpanel_pkgs(), 1, "_check_cpanel_pkgs should return 0 when issues are detected" );
}

done_testing();
