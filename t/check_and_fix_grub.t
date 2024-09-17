#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;
my $cmdline  = Test::MockFile->file('/proc/cmdline');
my $grub_cfg = Test::MockFile->file(Elevate::Constants::DEFAULT_GRUB_FILE);
my $mock_srs = Test::MockModule->new('Cpanel::SafeRun::Simple');
my $mock_sro = Test::MockModule->new('Cpanel::SafeRun::Object');

subtest "check_and_fix_grub kernel using net.ifnames=0" => sub {

    my $cpev = cpev->new;
    my $g2   = cpev->component('Grub2');

    $cmdline->contents( <<~'EOS' );
    BOOT_IMAGE=(hd0,msdos1)/boot/vmlinuz-4.18.0-425.10.1.el8_7.x86_64 root=UUID=6cd50e51-cfc6-40b9-9ec5-f32fa2e4ff02 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota net.ifnames=0
    EOS

    ok !$g2->post_distro_upgrade(), "grub file is missing";

    $grub_cfg->contents( <<~'EOS' );
    GRUB_TIMEOUT=5
    GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
    GRUB_DEFAULT=saved
    GRUB_DISABLE_SUBMENU=true
    GRUB_TERMINAL_OUTPUT="console"
    GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet rootflags=uquota"
    GRUB_DISABLE_RECOVERY="true"
    GRUB_ENABLE_BLSCFG=true
    EOS

    my $grubenv = <<~'EOS';
    saved_entry=cab9605edaa5484da7c2f02b8fd10762-4.18.0-425.10.1.el8_7.x86_64
    kernelopts=root=UUID=6cd50e51-cfc6-40b9-9ec5-f32fa2e4ff02 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota
    boot_success=0
    boot_indeterminate=0
    EOS

    $mock_srs->redefine( saferunnoerror => sub { return $grubenv } );
    $mock_sro->redefine(
        new_or_die => sub {
            my ( $class, %ARGS ) = @_;
            $grubenv = $ARGS{'args'}->[2];
            return bless {}, $class;
        }
    );

    ok $g2->post_distro_upgrade(), "check_and_fix_grub need to fixup grub config";

    is $grub_cfg->contents(), <<~'EOS', "file is fixed";
    GRUB_TIMEOUT=5
    GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
    GRUB_DEFAULT=saved
    GRUB_DISABLE_SUBMENU=true
    GRUB_TERMINAL_OUTPUT="console"
    GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet rootflags=uquota net.ifnames=0"
    GRUB_DISABLE_RECOVERY="true"
    GRUB_ENABLE_BLSCFG=true
    EOS

    like $grubenv, qr/^kernelopts=root=UUID=6cd50e51-cfc6-40b9-9ec5-f32fa2e4ff02 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota net\.ifnames=0\s*$/ma, "GRUB environment variable set correctly";

    ok !$g2->post_distro_upgrade(), "do not fix it twice";

    return;
};

subtest "check_and_fix_grub kernel without net.ifnames=0" => sub {

    my $cpev = cpev->new;
    my $g2   = cpev->component('Grub2');

    $cmdline->unlink;

    $grub_cfg->contents( <<~'EOS' );
    GRUB_TIMEOUT=5
    GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
    GRUB_DEFAULT=saved
    GRUB_DISABLE_SUBMENU=true
    GRUB_TERMINAL_OUTPUT="console"
    GRUB_CMDLINE_LINUX="crashkernel=auto rd.lvm.lv=centos/root rd.lvm.lv=centos/swap rhgb quiet rootflags=uquota"
    GRUB_DISABLE_RECOVERY="true"
    GRUB_ENABLE_BLSCFG=true
    EOS

    ok !$g2->post_distro_upgrade(), "no need to fix when current kernel does not use net.ifnames=0";

    $cmdline->contents("whatever");

    ok !$g2->post_distro_upgrade(), "no need to fix when current kernel does not use net.ifnames=0";

    return;
};

done_testing();
