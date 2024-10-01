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

my $grub2_comp = cpev->new->get_component('Grub2');

my $mock_g2 = Test::MockModule->new('Elevate::Components::Grub2');

my $mock_elevate = Test::MockFile->file('/var/cpanel/elevate');

my $mock_stage_file = Test::MockModule->new('Elevate::StageFile');
my $stage_data;
$mock_stage_file->redefine( _read_stage_file => sub { return $stage_data } );
$mock_stage_file->redefine( _save_stage_file => sub { $stage_data = $_[0]; return 1 } );

{
    note "Checking mark_cmdline";

    $stage_data = undef;

    my $mock_comp = Test::MockModule->new('Elevate::Components::Grub2');
    $mock_comp->redefine( _call_grubby    => 0 );
    $mock_comp->redefine( _default_kernel => "doesn't matter" );

    $grub2_comp->mark_cmdline();
    my $tag = $stage_data->{bootloader_random_tag};
    ok( 0 <= $tag && $tag < 100000, "tag value created as expected" );
    message_seen( 'INFO' => qq[Marking default boot entry with additional parameter "elevate-$tag".] );
    no_messages_seen();
}

{
    note "Checking verify_cmdline";

    my $mock_slurp = Test::MockModule->new('File::Slurper');
    my $cmdline;
    $mock_slurp->redefine( read_binary => sub { return $cmdline } );

    $mock_cpev->redefine( should_run_distro_upgrade => 1 );
    $mock_cpev->redefine( do_cleanup                => sub { $stage_data = undef; return; } );

    my $mock_comp = Test::MockModule->new('Elevate::Components::Grub2');
    $mock_comp->redefine( _default_kernel               => "kernel-image" );
    $mock_comp->redefine( _call_grubby                  => 0 );
    $mock_comp->redefine( _remove_but_dont_stop_service => 0 );

    $cmdline    = 'BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-4.18.0-513.11.1.el8_9.x86_64 root=UUID=cc6b4037-0469-45b1-9b87-e5d2c3bb1654 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash net.ifnames=0 nomodeset rootflags=uquota';
    $stage_data = { stage_number => 2 };
    trap { $grub2_comp->verify_cmdline() };
    is( $trap->exit, 69, "verify_cmdline exited with EX_UNAVAILABLE" );

    message_seen( 'INFO'  => qr/^Checking for "elevate-[0-9]{1,5}" in booted kernel's command line...$/ );
    message_seen( 'DEBUG' => "/proc/cmdline contains: $cmdline" );
    message_seen( 'ERROR' => "Parameter not detected. Attempt to upgrade is being aborted." );
    no_messages_seen();

    notification_seen( qr/^Failed to update to/, qr/the system has control over/ );
    no_notifications_seen();

    $cmdline    = 'BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-4.18.0-513.11.1.el8_9.x86_64 root=UUID=cc6b4037-0469-45b1-9b87-e5d2c3bb1654 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash net.ifnames=0 nomodeset rootflags=uquota elevate-9001';
    $stage_data = { stage_number => 2, bootloader_random_tag => 9001 };
    ok( lives { $grub2_comp->verify_cmdline() }, "verify_cmdline doesn't die" );

    message_seen( 'INFO'  => qq[Checking for "elevate-9001" in booted kernel's command line...] );
    message_seen( 'DEBUG' => "/proc/cmdline contains: $cmdline" );
    message_seen( 'INFO'  => "Parameter detected; restoring entry to original state." );
    no_messages_seen();

    no_notifications_seen();
}

{
    note "checking _blocker_blscfg: GRUB_ENABLE_BLSCFG state check";

    $mock_g2->redefine( '_blocker_grub2_workaround'    => 0 );
    $mock_g2->redefine( '_blocker_grub_not_installed'  => 0 );
    $mock_g2->redefine( '_blocker_grub_config_missing' => 0 );

    $mock_g2->redefine( _parse_shell_variable => sub { die "something happened\n" } );
    is(
        dies { $components->_check_single_blocker('Grub2') },
        "something happened\n",
        "blockers_check() handles an exception when there is a problem parsing /etc/default/grub"
    );

    $mock_g2->redefine( _parse_shell_variable => "false" );

    is $components->blockers(), [], 'no blockers';

    is $components->_check_single_blocker('Grub2'), 0;

    like(
        $components->blockers,
        [
            {
                id  => q[Elevate::Components::Grub2::_blocker_blscfg],
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
    $mock_g2->redefine( _grub2_workaround_state => Elevate::Components::Grub2::GRUB2_WORKAROUND_UNCERTAIN );

    my $grub2 = $components->_get_blocker_for('Grub2');

    like(
        $grub2->_blocker_grub2_workaround(),
        {
            id  => q[Elevate::Components::Grub2::_blocker_grub2_workaround],
            msg => qr/configuration of the GRUB2 bootloader/,
        },
        "uncertainty about whether GRUB2 workaround is present/needed blocks"
    );

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');

    #$grub2 = $blockers->_get_blocker_for('Grub2');
    my $stash = undef;
    $mock_g2->redefine(
        _grub2_workaround_state => Elevate::Components::Grub2::GRUB2_WORKAROUND_OLD,

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

    my $grub2 = $components->_get_blocker_for('Grub2');

    like(
        $grub2->_blocker_grub_not_installed(),
        {
            id  => q[Elevate::Components::Grub2::_blocker_grub_not_installed],
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

    my $grub2 = $components->_get_blocker_for('Grub2');

    like(
        $grub2->_blocker_grub_config_missing(),
        {
            id  => q[Elevate::Components::Grub2::_blocker_grub_config_missing],
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
