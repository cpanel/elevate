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
my $mock_g2    = Test::MockModule->new('Elevate::Components::Grub2ControlTest');

my $mock_grubby      = Test::MockFile->file( '/usr/sbin/grubby',      '', { mode => 0755 } );
my $mock_update_grub = Test::MockFile->file( '/usr/sbin/update-grub', '', { mode => 0755 } );
my $mock_elevate     = Test::MockFile->file('/var/cpanel/elevate');

my $mock_stage_file = Test::MockModule->new('Elevate::StageFile');
my $stage_data;
$mock_stage_file->redefine( _read_stage_file => sub { return $stage_data } );
$mock_stage_file->redefine( _save_stage_file => sub { $stage_data = $_[0]; return 1 } );

{
    note 'Checking _autofix_etc_default_grub';

    my $mock_file_slurper = Test::MockModule->new('File::Slurper');
    $mock_file_slurper->redefine(
        read_binary => sub { die "do not call this\n"; },
    );

    foreach my $os (qw{ cent cloud ubuntu }) {
        set_os_to($os);

        is( $grub2_comp->_autofix_etc_default_grub(), undef, 'Returns early on OSs where this is not needed' );
    }

    set_os_to('alma');

    my $content;
    my $actual_content;
    $mock_file_slurper->redefine(
        read_binary => sub { return $content; },
        write_text  => sub { $actual_content = $_[1]; },
    );

    $content = <<'EOS';
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL="serial console"
GRUB_ENABLE_BLSCFG=true
GRUB_SERIAL_COMMAND="serial --speed=115200"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota"
GRUB_DISABLE_RECOVERY="true"
EOS

    my $expected_content = $content;

    my $ssystem_and_die_params = [];
    $mock_g2->redefine(
        ssystem_and_die => sub {
            shift;
            my @args = @_;
            push @$ssystem_and_die_params, \@args;
            return;
        },
    );

    is( $grub2_comp->_autofix_etc_default_grub(), undef,           'Returns normally when it does not fix anything' );
    is( $expected_content,                        $actual_content, 'The expected content is written' );
    is( $ssystem_and_die_params,                  [],              'grub2-mkconfig was not called' );

    $content = <<'EOS';
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial --speed=115200"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota"
GRUB_DISABLE_RECOVERY="true"
EOS

    $expected_content = $content;
    $expected_content .= "GRUB_ENABLE_BLSCFG=true\n";

    is( $grub2_comp->_autofix_etc_default_grub(), undef,           'Returns normally when it adds the expected line to the config' );
    is( $expected_content,                        $actual_content, 'The expected content is written' );
    is(
        $ssystem_and_die_params,
        [
            [
                '/usr/sbin/grub2-mkconfig',
                '-o',
                '/boot/grub2/grub.cfg',
            ],
        ],
        'grub2-mkconfig was called as expected'
    );

    $content = <<'EOS';
GRUB_TIMEOUT=0
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL="serial console"
GRUB_SERIAL_COMMAND="serial --speed=115200"
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=foo
EOS

    $ssystem_and_die_params = [];

    is( $grub2_comp->_autofix_etc_default_grub(), undef,           'Returns normally when it modifies the expected line in the config' );
    is( $expected_content,                        $actual_content, 'The expected content is written' );
    is(
        $ssystem_and_die_params,
        [
            [
                '/usr/sbin/grub2-mkconfig',
                '-o',
                '/boot/grub2/grub.cfg',
            ],
        ],
        'grub2-mkconfig was called as expected'
    );
}

$mock_g2->redefine(
    _autofix_etc_default_grub => sub { return undef; },
);

{
    note "Checking mark_cmdline on CentOS 7 and AlmaLinux 8";
    foreach my $os (qw{ cent alma }) {
        set_os_to($os);

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
    note "Checking verify_cmdline on CentOS 7 and AlmaLinux 8";
    foreach my $os (qw{ cent alma }) {
        set_os_to($os);

        my $mock_slurp = Test::MockModule->new('File::Slurper');
        my $cmdline;
        $mock_slurp->redefine( read_binary => sub { return $cmdline } );

        $mock_cpev->redefine( upgrade_distro_manually => 0 );
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
}

{
    note "Checking verify_cmdline on Ubuntu 20";
    set_os_to('ubuntu');

    my $mock_config     = Test::MockFile->file( Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_FILE_PATH, 'CONTENT DOES NOT MATTER' );
    my $mock_config_dir = Test::MockFile->dir(Elevate::Components::Grub2ControlTest::GRUB_MKCONFIG_FRAG_DIR_PATH);

    my $mock_slurp = Test::MockModule->new('File::Slurper');
    my $cmdline;
    $mock_slurp->redefine( read_binary => sub { return $cmdline } );

    $mock_cpev->redefine( upgrade_distro_manually => 0 );
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
