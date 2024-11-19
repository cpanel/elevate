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
use Test::MockFile 0.032 qw<nostrict>;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $kcarectl      = '/usr/bin/kcarectl';
my $mock_kcarectl = Test::MockFile->file( $kcarectl, '' );

my $mock_comp      = Test::MockModule->new('Elevate::Components::KernelCare');
my $mock_pkgmgr    = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
my $mock_fetch     = Test::MockModule->new('Elevate::Fetch');
my $mock_file_copy = Test::MockModule->new('File::Copy');

my $comp = cpev->new->get_component('KernelCare');

{
    note 'Blocker behavior';

    set_os_to('cent');

    is( $comp->check(), undef, "Returns early when $kcarectl is not executable" );

    $mock_kcarectl->chmod(0755);
    is( $comp->check(), undef, 'Returns early when KernelCare is supported' );

    set_os_to('ubuntu');
    like(
        $comp->check(),
        {
            id  => q[Elevate::Components::KernelCare::check],
            msg => qr/ELevate does not currently support KernelCare for upgrades of/,
        },
        'Returns a blocker when KernelCare is not supported'
    );
}

{
    note 'pre_distro_upgrade';

    set_os_to('cent');
    $mock_kcarectl->chmod(0755);

    my @repos;
    $mock_pkgmgr->redefine(
        remove_pkgs_from_repos => sub { shift; @repos = @_; },
    );

    my @stage_file_data;
    $mock_stagefile->redefine(
        update_stage_file => sub { push @stage_file_data, @_; },
    );

    is( $comp->pre_distro_upgrade, undef, 'Returns undef' );

    is(
        \@repos,
        ['kernelcare'],
        'remove_pkgs_from_repos called for expected repo'
    );

    is(
        \@stage_file_data,
        [
            {
                reinstall => {
                    kernelcare => 1,
                },
            },
            {
                '_run_once' => {
                    'stage0_Elevate::Components::KernelCare::_remove_kernelcare_if_needed' => 1,
                },
            },
        ],
        'The expected info is added to the stage file'
    ) or diag explain \@stage_file_data;

    $mock_comp->redefine(
        _remove_kernelcare_if_needed => sub { die "do not call\n"; },
    );

    set_os_to('ubuntu');
    is( $comp->pre_distro_upgrade, undef, 'Returns early when KernelCare is not supported' );

    set_os_to('cloud');
    is( $comp->pre_distro_upgrade, undef, 'Returns early when leapp can handle KernelCare' );
}

{
    note 'post_distro_upgrade';

    clear_messages_seen();

    set_os_to('cent');

    my $mock_kcare_conf         = Test::MockFile->file( '/etc/sysconfig/kcare/kcare.conf',         '' );
    my $mock_kcare_conf_rpmsave = Test::MockFile->file( '/etc/sysconfig/kcare/kcare.conf.rpmsave', 'My very own customization' );
    my $mock_true               = Test::MockFile->file( '/usr/bin/true',                           '' );

    $mock_fetch->redefine(
        script => sub { return '/usr/bin/true'; },
    );

    $mock_file_copy->redefine(
        cp => 1,
    );

    my @ssystem_and_die_params = ();
    my @ssystem_params         = ();
    $mock_comp->redefine(
        ssystem_and_die => sub {
            shift;
            @ssystem_and_die_params = @_;
            return;
        },
        ssystem => sub {
            shift;
            @ssystem_params = @_;
            return;
        },
    );

    my $stage_data = {};
    $mock_stagefile->redefine(
        read_stage_file   => sub { diag explain $stage_data; return $stage_data; },
        update_stage_file => 1,
    );

    is( $comp->post_distro_upgrade, undef, 'Returns undef' );
    no_messages_seen();

    $stage_data = {
        kernelcare => 1,
    };

    is( $comp->post_distro_upgrade, undef, 'Returns undef' );
    message_seen( INFO => 'Restoring kernelcare' );
    message_seen( INFO => 'Retrieving kernelcare installer' );
    message_seen( INFO => 'Restoring Configuration file: /etc/sysconfig/kcare/kcare.conf' );
    message_seen( INFO => 'Running kernelcare installer' );

    is(
        \@ssystem_and_die_params,
        [
            '/usr/bin/bash',
            '/usr/bin/true',
        ],
        'The expected script is called'
    );

    message_seen( INFO => 'Updating kernelcare' );

    is(
        \@ssystem_params,
        [
            '/usr/bin/kcarectl',
            '--update',
        ],
    );

    $mock_comp->redefine(
        _restore_kernelcare => sub { die "do not call\n"; },
    );

    set_os_to('ubuntu');
    is( $comp->pre_distro_upgrade, undef, 'Returns early when KernelCare is not supported' );

    set_os_to('cloud');
    is( $comp->pre_distro_upgrade, undef, 'Returns early when leapp can handle KernelCare' );
}

done_testing();
