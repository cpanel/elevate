#!/usr/local/cpanel/3rdparty/bin/perl

# HARNESS-NO-STREAM

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

BEGIN {
    use FindBin;
    require $FindBin::Bin . '/../elevate-cpanel';
}

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

    $INC{"cpev.pm"} = '__here__';
    my $mock_cpev = Test::MockModule->new('cpev')    #
      ->redefine(
        '_blockers_check' => sub ($self) {

            # only perform a single check
            $self->_check_blocker('DiskSpace');
            return 0;
        }
      );

    is(
        dies { check_blocker( _abort_on_first_blocker => 1 ) },
        {
            id  => 99,
            msg => "disk space issue",
        },
        q{Block if disk space issues.}
    );

    $mock_ds->redefine( _disk_space_check => 1 );
    ok( check_blocker( _abort_on_first_blocker => 1 ), 'System is up to date' );
}

undef $mock_saferun;
undef $check;

done_testing;

sub check_blocker (@args) {    # helper for test...
                               #my $cpev = cpev->new;
    return cpev->new(@args)->_check_blocker('DiskSpace');
}
