#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - t/check_and_fix_grub.t                  Copyright 2023 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited
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

my $cpev = bless {}, 'cpev';

my $cmdline  = Test::MockFile->file('/proc/cmdline');
my $grub_cfg = Test::MockFile->file(cpev::DEFAULT_GRUB_FILE);

subtest "check_and_fix_grub kenel using net.ifnames=0" => sub {

    $cmdline->contents( <<~'EOS' );
    BOOT_IMAGE=(hd0,msdos1)/boot/vmlinuz-4.18.0-425.10.1.el8_7.x86_64 root=UUID=6cd50e51-cfc6-40b9-9ec5-f32fa2e4ff02 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 crashkernel=no nosplash nomodeset rootflags=uquota net.ifnames=0
    EOS

    ok !$cpev->check_and_fix_grub(), "grub file is missing";

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

    ok $cpev->check_and_fix_grub(), "check_and_fix_grub need to fixup grub config";

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

    ok !$cpev->check_and_fix_grub(), "do not fix it twice";

    return;
};

subtest "check_and_fix_grub kenel without net.ifnames=0" => sub {
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

    ok !$cpev->check_and_fix_grub(), "no need to fix when current kenel does not use net.ifnames=0";

    $cmdline->contents("whatever");

    ok !$cpev->check_and_fix_grub(), "no need to fix when current kenel does not use net.ifnames=0";

    return;
};

done_testing();
