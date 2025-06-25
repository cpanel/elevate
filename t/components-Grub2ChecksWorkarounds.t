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
use Test::Trap       qw/:output(perlio) :exit/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_cpev = Test::MockModule->new('cpev');

my $cpev       = cpev->new;
my $components = Elevate::Components->new( cpev => $cpev );

my $grub2_comp = cpev->new->get_component('Grub2ChecksWorkarounds');

my $mock_g2 = Test::MockModule->new('Elevate::Components::Grub2ChecksWorkarounds');

my $mock_grubby  = Test::MockFile->file( '/usr/sbin/grubby', '', { mode => 0755 } );
my $mock_elevate = Test::MockFile->file('/var/cpanel/elevate');

my $mock_stage_file = Test::MockModule->new('Elevate::StageFile');
my $stage_data;
$mock_stage_file->redefine( _read_stage_file => sub { return $stage_data } );
$mock_stage_file->redefine( _save_stage_file => sub { $stage_data = $_[0]; return 1 } );

{
    note "checking _blocker_blscfg: GRUB_ENABLE_BLSCFG state check";

    set_os_to( 'ubuntu', 20 );
    is( $components->_check_single_blocker('Grub2ChecksWorkarounds'), 1, 'Blocker is bypassed on Ubuntu upgrades' );

    set_os_to( 'cent', 7 );

    $mock_g2->redefine( '_blocker_grub2_workaround'    => 0 );
    $mock_g2->redefine( '_blocker_grub_not_installed'  => 0 );
    $mock_g2->redefine( '_blocker_grub_config_missing' => 0 );

    $mock_g2->redefine( _parse_shell_variable => sub { die "something happened\n" } );
    is(
        dies { $components->_check_single_blocker('Grub2ChecksWorkarounds') },
        "something happened\n",
        "blockers_check() handles an exception when there is a problem parsing /etc/default/grub"
    );

    $mock_g2->redefine( _parse_shell_variable => "false" );

    is $components->blockers(), [], 'no blockers';

    is $components->_check_single_blocker('Grub2ChecksWorkarounds'), 0;

    like(
        $components->blockers,
        [
            {
                id  => q[Elevate::Components::Grub2ChecksWorkarounds::_blocker_blscfg],
                msg => qr/^Disabling the BLS boot entry format prevents the resulting system from/,
            }
        ],
        "blocks when the shell variable is set to false"
    );

    $mock_g2->unmock('_blocker_grub2_workaround');
    $mock_g2->unmock('_blocker_grub_not_installed');
    $mock_g2->unmock('_blocker_grub_config_missing');
}

{
    note "grub2 work around.";
    $mock_g2->redefine( _grub2_workaround_state => Elevate::Components::Grub2ChecksWorkarounds::GRUB2_WORKAROUND_UNCERTAIN );

    my $grub2 = $components->_get_blocker_for('Grub2ChecksWorkarounds');

    like(
        $grub2->_blocker_grub2_workaround(),
        {
            id  => q[Elevate::Components::Grub2ChecksWorkarounds::_blocker_grub2_workaround],
            msg => qr/configuration of the GRUB2 bootloader/,
        },
        "uncertainty about whether GRUB2 workaround is present/needed blocks"
    );

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');

    #$grub2 = $blockers->_get_blocker_for('Grub2ChecksWorkarounds');
    my $stash = undef;
    $mock_g2->redefine(
        _grub2_workaround_state => Elevate::Components::Grub2ChecksWorkarounds::GRUB2_WORKAROUND_OLD,

        #update_stage_file       => sub ( $, $data ) { $stash = $data },
    );
    $mock_stagefile->redefine(
        update_stage_file => sub ($data) { $stash = $data },
    );

    is( $grub2->_blocker_grub2_workaround(),                       0, 'Blockers still pass...' );
    is( $stash->{'grub2_workaround'}->{'needs_workaround_update'}, 1, "...but we found the GRUB2 workaround and need to update it" );
}

{
    note "grub2 package presence";

    my $grub2_installed = 0;
    my $mock_pkgr       = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine(
        is_installed => sub { return $grub2_installed; },
    );

    my $grub2 = $components->_get_blocker_for('Grub2ChecksWorkarounds');

    like(
        $grub2->_blocker_grub_not_installed(),
        {
            id  => q[Elevate::Components::Grub2ChecksWorkarounds::_blocker_grub_not_installed],
            msg => qr/grub2-pc package is not installed/,
        },
        'Returns blocker if GRUB2 is not installed'
    );

    $grub2_installed = 1;
    is( $grub2->_blocker_grub_not_installed(), 0, 'No blocker if GRUB2 is installed' );
}

{
    note "grub2 config file presence";

    my $mock_cfg1 = Test::MockFile->file('/boot/grub/grub.cfg');
    my $mock_cfg2 = Test::MockFile->file('/boot/grub2/grub.cfg');

    my $grub2 = $components->_get_blocker_for('Grub2ChecksWorkarounds');

    like(
        $grub2->_blocker_grub_config_missing(),
        {
            id  => q[Elevate::Components::Grub2ChecksWorkarounds::_blocker_grub_config_missing],
            msg => qr/config file is missing/,
        },
        'Returns blocker if neither config file present'
    );

    $mock_cfg1->contents('stuff');
    is( $grub2->_blocker_grub_config_missing(), 0, 'No blocker if only one grub2 config file is present' );

    $mock_cfg1->unlink();
    $mock_cfg2->contents('other stuff');
    is( $grub2->_blocker_grub_config_missing(), 0, 'No blocker if only the other grub2 config file is present' );

    $mock_cfg1->contents('stuff');
    is( $grub2->_blocker_grub_config_missing(), 0, 'No blocker if both grub2 config files are present' );
}

done_testing();
