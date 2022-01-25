#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

# cpanel - ./t/disk_space.t                        Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;

require $FindBin::Bin . '/../elevate-cpanel';

my $saferun_output;

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub {
        $saferun_output;
    }
);

like(
    dies { cpev::_disk_space_check() },
    qr{Cannot parse df output},
    "_disk_space_check"
);

$saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 74579968   9294828  89% /
EOS

like(
    dies { cpev::_disk_space_check() },
    qr{expected 3 lines ; got 1 lines},
    "_disk_space_check"
);

$saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

is cpev::_disk_space_check(), 1, "_disk_space_check ok";

my $boot = 121 * 1_024;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   $boot  91% /
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

is cpev::_disk_space_check(), 1, "_disk_space_check ok - /boot 121 M";

$boot = 119 * 1_024;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   $boot  91% /
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

my $check;
like(
    warnings { $check = cpev::_disk_space_check() },
    [qr{/boot needs 120 M => available 119 M}],
    q[Got expected warnings]
);

is $check, 0, "_disk_space_check failure - /boot 119 M";

my $usr_local_cpanel = 2 * 1_024**2;    # 2 G in K

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   7567104 91% /
/dev/vda1       83874796 76307692   $usr_local_cpanel  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

is cpev::_disk_space_check(), 1, "_disk_space_check ok - /usr/local/cpanel 2 G";

$usr_local_cpanel = 1.4 * 1_024**2;     # 2 G in K

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   7567104 91% /
/dev/vda1       83874796 76307692   $usr_local_cpanel  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

like(
    warnings { $check = cpev::_disk_space_check() },
    [qr{/usr/local/cpanel needs 1.50 G => available 1.40 G}],
    q[Got expected warnings]
);

is $check, 0, "_disk_space_check failure - /usr/local/cpanel 1.4 G";

done_testing;
