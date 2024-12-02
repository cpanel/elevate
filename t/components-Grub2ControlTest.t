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
use Test::Trap       qw/:output(perlio) :die :exit/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_cpev = Test::MockModule->new('cpev');

my $cpev       = cpev->new;
my $components = Elevate::Components->new( cpev => $cpev );

my $grub2_comp = cpev->new->get_component('Grub2ControlTest');

my $mock_g2 = Test::MockModule->new('Elevate::Components::Grub2ControlTest');

my $mock_grubby      = Test::MockFile->file( '/usr/sbin/grubby',      '', { mode => 0755 } );
my $mock_update_grub = Test::MockFile->file( '/usr/sbin/update-grub', '', { mode => 0755 } );
my $mock_elevate     = Test::MockFile->file('/var/cpanel/elevate');

my $mock_stage_file = Test::MockModule->new('Elevate::StageFile');
my $stage_data;
$mock_stage_file->redefine( _read_stage_file => sub { return $stage_data } );
$mock_stage_file->redefine( _save_stage_file => sub { $stage_data = $_[0]; return 1 } );

{
    note "Checking mark_cmdline on CentOS 7";
    set_os_to('cent');

    $stage_data = undef;

    my $mock_comp = Test::MockModule->new('Elevate::Components::Grub2ControlTest');
    $mock_comp->redefine( _call_grubby    => 0 );
    $mock_comp->redefine( _default_kernel => "doesn't matter" );

    $grub2_comp->mark_cmdline();
    my $tag = $stage_data->{bootloader_random_tag};
    ok( 0 <= $tag && $tag < 100000, "tag value created as expected" );
    message_seen( 'INFO' => qq[Marking default boot entry with additional parameter "elevate-$tag".] );
    no_messages_seen();
}

{
    note "Checking mark_cmdline on Ubuntu 20";
    set_os_to('ubuntu');

    $stage_data = undef;

    my $mock_config_dir = Test::MockFile->dir(Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_DIR_PATH);
    mkdir Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_DIR_PATH, 0755;
    my $mock_config = Test::MockFile->file(Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_FILE_PATH);

    my $mock_comp = Test::MockModule->new('Elevate::Components::Grub2ControlTest');
    $mock_comp->redefine( _call_update_grub => 0 );

    $grub2_comp->mark_cmdline();
    my $tag = $stage_data->{bootloader_random_tag};
    ok( 0 <= $tag && $tag < 100000, "tag value created as expected" );
    message_seen( 'INFO' => qq[Marking default boot entry with additional parameter "elevate-$tag".] );
    no_messages_seen();
}

{
    note "Checking verify_cmdline on CentOS 7";
    set_os_to('cent');    # Famous last words: results should not differ for CL7

    my $mock_slurp = Test::MockModule->new('File::Slurper');
    my $cmdline;
    $mock_slurp->redefine( read_binary => sub { return $cmdline } );

    $mock_cpev->redefine( upgrade_distro_manually => 1 );
    $mock_cpev->redefine( do_cleanup              => sub { $stage_data = undef; return; } );

    my $mock_comp = Test::MockModule->new('Elevate::Components::Grub2ControlTest');
    $mock_comp->redefine( _default_kernel               => "kernel-image" );
    $mock_comp->redefine( _call_grubby                  => 0 );
    $mock_comp->redefine( _remove_but_dont_stop_service => 0 );

    $cmdline    = 'BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-4.18.0-513.11.1.el8_9.x86_64 root=UUID=cc6b4037-0469-45b1-9b87-e5d2c3bb1654 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash net.ifnames=0 nomodeset rootflags=uquota';
    $stage_data = { stage_number => 2 };
    trap { $grub2_comp->verify_cmdline() };
    is( $trap->exit, 69, "verify_cmdline exited with EX_UNAVAILABLE" );
    if ( $trap->leaveby eq 'die' ) {
        diag( "verify_cmdline died with an exception: " . $trap->die );
    }
    elsif ( $trap->leaveby eq 'return' ) {
        diag("verify_cmdline unexpectedly returned normally");
    }

    message_seen( 'INFO'  => qr/^Checking for "elevate-[0-9]{1,5}" in booted kernel's command line...$/ );
    message_seen( 'DEBUG' => "/proc/cmdline contains: $cmdline" );
    message_seen( 'ERROR' => "Parameter not detected. Attempt to upgrade is being aborted." );
    no_messages_seen();

    notification_seen( qr/^Failed to update to/, qr/the system has control over/ );
    no_notifications_seen();

    $cmdline    = 'BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-4.18.0-513.11.1.el8_9.x86_64 root=UUID=cc6b4037-0469-45b1-9b87-e5d2c3bb1654 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash net.ifnames=0 nomodeset rootflags=uquota elevate-9001';
    $stage_data = { stage_number => 2, bootloader_random_tag => 9001 };
    ok( lives { $grub2_comp->verify_cmdline() }, "verify_cmdline doesn't die" ) or diag $@;

    message_seen( 'INFO'  => qq[Checking for "elevate-9001" in booted kernel's command line...] );
    message_seen( 'DEBUG' => "/proc/cmdline contains: $cmdline" );
    message_seen( 'INFO'  => "Parameter detected; restoring entry to original state." );
    no_messages_seen();

    no_notifications_seen();
}

{
    note "Checking verify_cmdline on Ubuntu 20";
    set_os_to('ubuntu');

    my $mock_config     = Test::MockFile->file( Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_FILE_PATH, 'CONTENT DOES NOT MATTER' );
    my $mock_config_dir = Test::MockFile->dir(Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_DIR_PATH);

    my $mock_slurp = Test::MockModule->new('File::Slurper');
    my $cmdline;
    $mock_slurp->redefine( read_binary => sub { return $cmdline } );

    $mock_cpev->redefine( upgrade_distro_manually => 1 );
    $mock_cpev->redefine( do_cleanup              => sub { $stage_data = undef; return; } );

    my $mock_comp = Test::MockModule->new('Elevate::Components::Grub2ControlTest');
    $mock_comp->redefine( _call_update_grub             => 0 );
    $mock_comp->redefine( _remove_but_dont_stop_service => 0 );

    $cmdline    = 'BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-4.18.0-513.11.1.el8_9.x86_64 root=UUID=cc6b4037-0469-45b1-9b87-e5d2c3bb1654 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash net.ifnames=0 nomodeset rootflags=uquota';
    $stage_data = { stage_number => 2 };
    trap { $grub2_comp->verify_cmdline() };
    is( $trap->exit, 69, "verify_cmdline exited with EX_UNAVAILABLE" );
    if ( $trap->leaveby eq 'die' ) {
        diag( "verify_cmdline died with an exception: " . $trap->die );
    }
    elsif ( $trap->leaveby eq 'return' ) {
        diag("verify_cmdline unexpectedly returned normally");
    }

    message_seen( 'INFO'  => qr/^Checking for "elevate-[0-9]{1,5}" in booted kernel's command line...$/ );
    message_seen( 'DEBUG' => "/proc/cmdline contains: $cmdline" );
    message_seen( 'ERROR' => "Parameter not detected. Attempt to upgrade is being aborted." );
    no_messages_seen();

    notification_seen( qr/^Failed to update to/, qr/the system has control over/ );
    no_notifications_seen();

    $cmdline    = 'BOOT_IMAGE=(hd0,gpt2)/boot/vmlinuz-4.18.0-513.11.1.el8_9.x86_64 root=UUID=cc6b4037-0469-45b1-9b87-e5d2c3bb1654 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash net.ifnames=0 nomodeset rootflags=uquota elevate-9001';
    $stage_data = { stage_number => 2, bootloader_random_tag => 9001 };
    $mock_config->contents('CONTENT DOES NOT MATTER');
    ok( lives { $grub2_comp->verify_cmdline() }, "verify_cmdline doesn't die" ) or diag $@;

    message_seen( 'INFO'  => qq[Checking for "elevate-9001" in booted kernel's command line...] );
    message_seen( 'DEBUG' => "/proc/cmdline contains: $cmdline" );
    message_seen( 'INFO'  => "Parameter detected; restoring entry to original state." );
    no_messages_seen();

    no_notifications_seen();
}

done_testing();
