#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;
use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Elevate::Blockers::DiskSpace ();

use cPstrict;

# aliases for testing
use constant MEG => Elevate::Blockers::DiskSpace::MEG();
use constant GIG => Elevate::Blockers::DiskSpace::GIG();

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
    qr{expected 3 lines ; got 1 lines},
    "_disk_space_check"
);

$saferun_output = <<EOS;
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

is( check_blocker(), 1, "_disk_space_check ok" );

my $boot = 121 * MEG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   $boot  91% /
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

is( check_blocker(), 1, "_disk_space_check ok - /boot 121 M" );

$boot = 119 * MEG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   $boot  91% /
/dev/vda1       83874796 76307692   7567104  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

my $check;
like(
    warnings { $check = check_blocker() },
    [qr{/boot needs 120 M => available 119 M}],
    q[Got expected warnings]
);

is $check, 0, "_disk_space_check failure - /boot 119 M";

my $usr_local_cpanel = 2 * GIG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   7567104 91% /
/dev/vda1       83874796 76307692   $usr_local_cpanel  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

is( check_blocker(), 1, "_disk_space_check ok - /usr/local/cpanel 2 G" );

$usr_local_cpanel = 1.4 * GIG;

$saferun_output = <<"EOS";
Filesystem     1K-blocks     Used Available Use% Mounted on
/dev/vda1       83874796 76307692   7567104 91% /
/dev/vda1       83874796 76307692   $usr_local_cpanel  91% /
/dev/vda1       83874796 76307692   7567104  91% /
EOS

like(
    warnings { $check = check_blocker() },
    [qr{/usr/local/cpanel needs 1.50 G => available 1.40 G}],
    q[Got expected warnings]
);

is $check, 0, "_disk_space_check failure - /usr/local/cpanel 1.4 G";

{
    note "disk space blocker.";

    my $mock_ds = Test::MockModule->new('Elevate::Blockers::DiskSpace');
    $mock_ds->redefine( _disk_space_check => 0 );

    my $blockers = cpev->new()->blockers;
    is $blockers->_check_single_blocker('DiskSpace'), 0;

    is(
        $blockers->blockers,
        [
            {
                id  => q[Elevate::Blockers::DiskSpace::check],
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

    my $blockers = cpev->new(@args)->blockers;
    my $ds       = $blockers->_get_blocker_for('DiskSpace');

    return $ds->check;
}
