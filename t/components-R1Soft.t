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

my $r1soft = cpev->new->component('R1Soft');

{
    note "Checking pre_distro_upgrade";

    my $stage_file_data;
    my $is_installed;
    my $yum_remove_called;
    my @enabled_repos = (
        "cpanel-plugins",
        "base/7/x86_64",
        "col",
        "col-extras/7/x86_64",
        "epel/x86_64",
        "extras/7/x86_64",
        "mysql-connectors-community/x86_64",
        "mysql-tools-community/x86_64",
        "mysql57-community/x86_64",
        "!openSUSE_Tools",
        "r1soft/x86_64",
        "updates/7/x86_64",
    );
    my @all_repos = (
        "base/7/x86_64",
        "base-debuginfo/x86_64",
        "base-source/7",
        "c7-media",
        "centos-kernel",
        "centos-kernel-experimental",
        "centos-sclo-rh/x86_64",
        "centosplus/7/x86_64",
        "centosplus-source/7",
        "col",
        "col-extras/7/x86_64",
        "col-extras-source",
        "col-source",
        "cr/7/x86_64",
        "epel/x86_64",
        "!mysql80-community/x86_64",
        "mysql80-community-debuginfo/x86_64",
        "mysql80-community-source",
        "!openSUSE_Tools",
        "r1soft/x86_64",
        "updates/7/x86_64",
        "updates-source/7",
    );

    my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine(
        is_installed => sub { return $is_installed; },
    );

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        update_stage_file => sub { $stage_file_data = shift; },
    );

    my $mock_yum = Test::MockModule->new('Elevate::YUM');
    $mock_yum->redefine(
        remove           => sub { $yum_remove_called = 1; },
        repolist_enabled => sub { return @enabled_repos; },
        repolist_all     => sub { return @all_repos; },
    );

    # Test when agent is not installed
    $is_installed      = 0;
    $yum_remove_called = 0;

    $r1soft->pre_distro_upgrade();
    is( $yum_remove_called, 0, 'Yum remove was not invoked when agent not installed' );
    is(
        $stage_file_data,
        {
            r1soft => {
                agent_installed => 0,
                repo_present    => 0,
                repo_enabled    => 0,
            }
        },
        'Correctly reports that the agent is not installed'
    );

    # Agent installed, repo present & enabled
    $is_installed      = 1;
    $yum_remove_called = 0;

    $r1soft->pre_distro_upgrade();
    is( $yum_remove_called, 1, 'Yum remove called when agent is installed' );
    is(
        $stage_file_data,
        {
            r1soft => {
                agent_installed => 1,
                repo_present    => 1,
                repo_enabled    => 1,
            }
        },
        'Correctly reports the installed agent and the repo is present and enabled'
    );

    # Agent installed, repo present, but not enabled
    $yum_remove_called = 0;
    @enabled_repos     = grep { !/^r1soft/ } @enabled_repos;

    $r1soft->pre_distro_upgrade();
    is( $yum_remove_called, 1, 'Yum remove called when agent is installed' );
    is(
        $stage_file_data,
        {
            r1soft => {
                agent_installed => 1,
                repo_present    => 1,
                repo_enabled    => 0,
            }
        },
        'Correctly reports the installed agent and the repo is present and not enabled'
    );

    # Agent installed, repo neither present nor enabled
    $yum_remove_called = 0;
    @all_repos         = grep { !/^r1soft/ } @all_repos;

    $r1soft->pre_distro_upgrade();
    is( $yum_remove_called, 1, 'Yum remove called when agent is installed' );
    is(
        $stage_file_data,
        {
            r1soft => {
                agent_installed => 1,
                repo_present    => 0,
                repo_enabled    => 0,
            }
        },
        'Correctly reports the installed agent and the repo is present and not enabled'
    );
}

{
    note "Checking post_distro_upgrade";

    my $stage_file_data;
    my $yum_install_called;
    my $create_repo_called;
    my $enable_repo_called;
    my $disable_repo_called;

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        read_stage_file => sub { return $stage_file_data; },
    );

    my $mock_yum = Test::MockModule->new('Elevate::YUM');
    $mock_yum->redefine(
        install => sub { $yum_install_called = 1; },
    );

    my $mock_r1soft = Test::MockModule->new('Elevate::Components::R1Soft');
    $mock_r1soft->redefine(
        _create_r1soft_repo  => sub { $create_repo_called  = 1 },
        _enable_r1soft_repo  => sub { $enable_repo_called  = 1 },
        _disable_r1soft_repo => sub { $disable_repo_called = 1 },
    );

    # Agent was not installed
    $stage_file_data = {
        agent_installed => 0,
        repo_present    => 0,
        repo_enabled    => 0,
    };
    ( $yum_install_called, $create_repo_called, $enable_repo_called, $disable_repo_called ) = ( 0, 0, 0, 0 );

    $r1soft->post_distro_upgrade();
    is( $yum_install_called,  0, 'Yum install not called when agent was not installed' );
    is( $create_repo_called,  0, 'Create repo not called when agent was not installed' );
    is( $enable_repo_called,  0, 'Enable repo not called when agent was not installed' );
    is( $disable_repo_called, 0, 'Disable repo not called when agent was not installed' );

    # Agent installed, repo present & enabled
    $stage_file_data = {
        agent_installed => 1,
        repo_present    => 1,
        repo_enabled    => 1,
    };
    ( $yum_install_called, $create_repo_called, $enable_repo_called, $disable_repo_called ) = ( 0, 0, 0, 0 );

    $r1soft->post_distro_upgrade();
    is( $yum_install_called,  1, 'Yum install called when agent was installed' );
    is( $create_repo_called,  0, 'Create repo not called when repo present' );
    is( $enable_repo_called,  0, 'Enable repo not called when repo already enabled' );
    is( $disable_repo_called, 0, 'Disable repo not called when repo present and enabled' );

    # Agent installed, repo present & not enabled
    $stage_file_data = {
        agent_installed => 1,
        repo_present    => 1,
        repo_enabled    => 0,
    };
    ( $yum_install_called, $create_repo_called, $enable_repo_called, $disable_repo_called ) = ( 0, 0, 0, 0 );

    $r1soft->post_distro_upgrade();
    is( $yum_install_called,  1, 'Yum install called when agent was installed' );
    is( $create_repo_called,  0, 'Create repo not called when repo present' );
    is( $enable_repo_called,  1, 'Enable repo called when repo not already enabled' );
    is( $disable_repo_called, 1, 'Disable repo called when repo present and not enabled' );

    # Agent installed, repo not present & not enabled
    $stage_file_data = {
        agent_installed => 1,
        repo_present    => 0,
        repo_enabled    => 0,
    };
    ( $yum_install_called, $create_repo_called, $enable_repo_called, $disable_repo_called ) = ( 0, 0, 0, 0 );

    $r1soft->post_distro_upgrade();
    is( $yum_install_called,  1, 'Yum install called when agent was installed' );
    is( $create_repo_called,  1, 'Create repo called when repo not present' );
    is( $enable_repo_called,  0, 'Enable repo not called when repo not present' );
    is( $disable_repo_called, 1, 'Disable repo called when repo not present' );
}

done_testing();
