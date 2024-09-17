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

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $ccs = bless {}, 'Elevate::Components::CCS';

my $mock_ccs       = Test::MockModule->new('Elevate::Components::CCS');
my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');

{
    note "Checking pre_distro_upgrade";

    my $installed = 0;

    my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine(
        is_installed => sub { return $installed; },
    );

    $mock_stagefile->redefine(
        update_stage_file => 0,
    );

    my $called__load_ccs_modules  = 0;
    my $called_clean_up_pkg_cruft = 0;
    my @called_for_user;
    my @ssystem_and_die_params;
    $mock_ccs->redefine(
        _load_ccs_modules            => sub { $called__load_ccs_modules = 1; },
        _ensure_export_directory     => 0,
        _export_data_for_single_user => sub ( $self, $user ) { push @called_for_user, $user; },
        clean_up_pkg_cruft           => sub { $called_clean_up_pkg_cruft = 1; },
        run_once                     => sub { $ccs->export_ccs_data(); },
        ssystem_and_die              => sub {
            shift;
            @ssystem_and_die_params = @_;
            return;
        },
    );

    is( $ccs->pre_distro_upgrade(), undef, 'pre_distro_upgrade is basically a noop if CCS is not installed' );
    is( $called__load_ccs_modules,  0,     'pre_distro_upgrade returned before loading CCS modules when CCS was not installed' );

    my @cpusers                  = qw{ foo bar baz };
    my $mock_cpanel_config_users = Test::MockModule->new('Cpanel::Config::Users');
    $mock_cpanel_config_users->redefine(
        getcpusers => sub { return @cpusers; },
    );

    $installed = 1;

    $ccs->pre_distro_upgrade();
    is( $called__load_ccs_modules, 1, '_load_ccs_modules is called when CCS is installed' );

    message_seen( 'INFO', qr/^Exporting CCS data to/ );

    is( \@called_for_user, \@cpusers, 'The expected users had data exported' );

    is(
        \@ssystem_and_die_params,
        [qw{ /usr/bin/yum -y remove cpanel-ccs-calendarserver cpanel-z-push }],
        'The expected packages were removed'
    );

    is( $called_clean_up_pkg_cruft, 1, 'Package cruft leftover after removal was cleaned up' );

    for my $user (@cpusers) {
        message_seen( 'INFO', "    Exporting data for $user" );
    }

    message_seen( 'INFO', 'Completed exporting CCS data for all users' );

    no_messages_seen();
}

{
    note "Checking post_distro_upgrade";

    my $installed = 0;
    $mock_stagefile->redefine(
        read_stage_file => sub { return $installed; },
    );

    my $ssystem_and_die_params = [];
    my @called_for_user;
    $mock_ccs->redefine(
        ssystem_and_die => sub {
            shift;
            push @{$ssystem_and_die_params}, @_;
            return;
        },
        ssystem => sub {
            shift;
            push @{$ssystem_and_die_params}, @_;
            return;
        },
        _ensure_ccs_service_is_up    => 0,
        move_pgsql_directory         => 0,
        move_pgsql_directory_back    => 0,
        run_once                     => sub { $_[0]->can( $_[1] )->( $_[0] ) },
        _import_data_for_single_user => sub ( $self, $user ) { push @called_for_user, $user; },
    );

    is( $ccs->post_distro_upgrade(), undef, 'post_distro_upgrade is a noop if CCS was not installed' );
    is( $ssystem_and_die_params,     [],    'No system commands were called when CCS was not installed' );

    my @cpusers;
    my $mock_cpanel_config_users = Test::MockModule->new('Cpanel::Config::Users');
    $mock_cpanel_config_users->redefine(
        getcpusers => sub { return @cpusers; },
    );

    $installed = 1;

    $ccs->post_distro_upgrade();

    message_seen( 'INFO', 'Importing CCS data' );

    is(
        $ssystem_and_die_params,
        [
            qw{/usr/bin/dnf -y install cpanel-ccs-calendarserver cpanel-z-push},
            qw{/usr/local/cpanel/bin/servers_queue run},
        ],
        'The expected commands are called during post_distro_upgrade when CCS was installed',
    );

    is( \@called_for_user, \@cpusers, 'CCS data was imported for the expected users' );

    foreach my $user (@cpusers) {
        message_seen( 'INFO', "    Importing data for $user" );
    }

    message_seen( 'INFO', 'Completed importing CCS data for all users' );

    no_messages_seen();
}

done_testing();
