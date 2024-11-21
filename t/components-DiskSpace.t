#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;
use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Elevate::Components::DiskSpace ();

use cPstrict;

# aliases for testing
use constant MEG => Elevate::Components::DiskSpace::MEG();
use constant GIG => Elevate::Components::DiskSpace::GIG();

my $saferun_output;

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub {
        $saferun_output;
    }
);

like(
    dies { check_blocker() },
    qr{Cannot parse df output},
    "_disk_space_check"
);

$saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 74579968   9294828  89% /
EOS

like(
    dies { check_blocker() },
    qr{expected 5 lines ; got 1 lines},
    "_disk_space_check"
);

$saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

is( check_blocker(), 1, "_disk_space_check ok" );

my $boot = 201 * MEG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   $boot    56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

is( check_blocker(), 1, "_disk_space_check ok - /boot 201 M" );

$boot = 199 * MEG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   $boot    56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

my $check;
like(
    warnings { $check = check_blocker() },
    [qr{/boot needs 200 M => available 199 M}],
    q[Got expected warnings]
);

is $check, 0, "_disk_space_check failure - /boot 119 M";

my $usr_local_cpanel = 2 * GIG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   $usr_local_cpanel  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

is( check_blocker(), 1, "_disk_space_check ok - /usr/local/cpanel 2 G" );

$usr_local_cpanel = 1.4 * GIG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       20134592 11245932   8872276  56% /
/dev/vda1       20134592 11245932   8872276  56% /
/dev/loop6        714624       92    677364   1% /tmp
/dev/vda1       20134592 11245932   $usr_local_cpanel  56% /
/dev/vda1       20134592 11245932   8872276  56% /
EOS

like(
    warnings { $check = check_blocker() },
    [qr{/usr/local/cpanel needs 1.50 G => available 1.40 G}],
    q[Got expected warnings]
);

is $check, 0, "_disk_space_check failure - /usr/local/cpanel 1.4 G";

{
    note "disk space blocker.";

    my $mock_ds = Test::MockModule->new('Elevate::Components::DiskSpace');
    $mock_ds->redefine( _disk_space_check => 0 );

    my $components = cpev->new()->components;
    is $components->_check_single_blocker('DiskSpace'), 0;

    is(
        $components->blockers,
        [
            {
                id  => q[Elevate::Components::DiskSpace::check],
                msg => "disk space issue",
            }
        ],
        q{Block if disk space issues.}
    );

    $mock_ds->redefine( _disk_space_check => 1 );
    ok( check_blocker(), 'System is up to date' );
}

undef $mock_saferun;
undef $check;

done_testing;
exit;

sub check_blocker (@args) {    # helper for test...

    my $components = cpev->new(@args)->components;
    my $ds         = $components->_get_blocker_for('DiskSpace');

    return $ds->check;
}
