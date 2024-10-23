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

my $acronis = cpev->new->get_component('Acronis');

{
    note "Checking pre_distro_upgrade";

    my $is_installed;
    my $yum_remove_called;
    my $stage_file_data;

    my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine(
        is_installed => sub { return $is_installed; },
    );

    my $mock_yum = Test::MockModule->new('Elevate::YUM');
    $mock_yum->redefine(
        remove => sub { $yum_remove_called = 1; },
    );

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        update_stage_file => sub { $stage_file_data = shift; },
    );

    # Test when Acronis is not installed
    $is_installed      = 0;
    $yum_remove_called = 0;
    $stage_file_data   = {};

    $acronis->pre_distro_upgrade();
    is( $yum_remove_called, 0,  'When package not installed:  did not uninstall package' );
    is( $stage_file_data,   {}, 'When package not installed:  did not update the stage file' );

    # Test when Acronis is installed
    $is_installed      = 1;
    $yum_remove_called = 0;
    $stage_file_data   = {};

    $acronis->pre_distro_upgrade();
    is( $yum_remove_called, 1, 'When package is installed:  uninstalled package' );
    is(
        $stage_file_data,
        {
            'reinstall' => {
                'acronis' => 1,
            },
        },
        'When package is installed:  updated the stage file'
    );
}

{
    note "Checking post_distro_upgrade";

    my $stage_file_data;
    my $dnf_install_called;

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        read_stage_file => sub { return $stage_file_data; },
    );

    my $mock_dnf = Test::MockModule->new('Elevate::DNF');
    $mock_dnf->redefine(
        install => sub { $dnf_install_called = 1; },
    );

    # Test when had not been installed
    $stage_file_data    = {};
    $dnf_install_called = 0;

    $acronis->post_distro_upgrade();
    is( $dnf_install_called, 0, 'When package was never installed:  did not reinstall' );

    # Test when had been installed
    $stage_file_data    = { 'acronis' => 1 };
    $dnf_install_called = 1;

    $acronis->post_distro_upgrade();
    is( $dnf_install_called, 1, 'When package had been installed:  reinstalled package' );
}

done_testing();
