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

my $mock_pkgmgr    = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');

my $comp = cpev->new->get_component('cPanelPlugins');

{
    note 'pre_distro_upgrade';

    $mock_pkgmgr->redefine(
        pkg_list => sub { die "do not call\n"; },
    );

    set_os_to('ubuntu');
    is( $comp->pre_distro_upgrade, undef, 'Returns early on ubuntu systems' );

    set_os_to('cent');

    my $cpanel_plugin_pkgs = [];
    $mock_pkgmgr->redefine(
        pkg_list => sub {
            return {
                'foo' => [
                    {
                        package => 'no',
                    },
                ],
                'bar' => [
                    {
                        package => 'soup',
                    },
                ],
                'cpanel-plugin-thing' => $cpanel_plugin_pkgs,
              },
              ;
        },
    );

    my $stage_info = {};
    $mock_stagefile->redefine(
        update_stage_file => sub { ($stage_info) = @_; },
    );

    is( $comp->pre_distro_upgrade, undef, 'Returns undef' );
    is( $stage_info,               {},    'Stage file is not updated when there are no installed cPanel plugins' );

    $cpanel_plugin_pkgs = [
        {
            package => 'bob',
        },
        {
            package => 'uncle',
        },
    ];

    is( $comp->pre_distro_upgrade, undef, 'Returns undef' );
    is(
        $stage_info,
        {
            restore => {
                yum => [
                    'bob',
                    'uncle',
                ],
            },
        },
        'The expected packages are listed in the stage file',
    );
}

{
    note 'post_distro_upgrade';

    $mock_stagefile->redefine(
        read_stage_file => sub { die "do not call\n"; },
    );

    set_os_to('ubuntu');
    is( $comp->post_distro_upgrade, undef, 'Returns early on ubuntu systems' );

    set_os_to('cent');

    my $stage_data = {};
    $mock_stagefile->redefine(
        read_stage_file => sub { return $stage_data; },
    );

    is( $comp->post_distro_upgrade, undef, 'Returns early when there is nothing to reinstall' );
    no_messages_seen();

    $stage_data = {
        restore => {
            yum => [
                'bob',
                'uncle',
            ],
        },
    };

    my @reinstall_args;
    $mock_pkgmgr->redefine(
        reinstall => sub { shift; @reinstall_args = @_; },
    );

    is( $comp->post_distro_upgrade, undef, 'Return undef' );
    message_seen( INFO => 'Restoring cPanel yum-based-plugins' );
    is(
        \@reinstall_args,
        [
            'bob',
            'uncle',
        ],
        'Reinstalls the correctly staged packages',
    );
}

done_testing();
