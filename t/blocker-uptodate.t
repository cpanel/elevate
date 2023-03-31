#!/usr/local/cpanel/3rdparty/bin/perl

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

require $FindBin::Bin . '/../elevate-cpanel';

my $cpev = cpev->new;

#my $blocker = Elevate::Blockers::UpToDate->new( cpev => $cpev );

my $script_mock = Test::MockModule->new('Elevate::Script');
$script_mock->redefine( '_build_latest_version' => cpev::VERSION );

{
    note "checking script update check";

    $script_mock->redefine( '_build_latest_version' => sub { return undef } );

    my $blockers = Elevate::Blockers->new( cpev => $cpev );

    is(
        $blockers->_check_single_blocker('UpToDate'),
        {
            id  => q[Elevate::Blockers::UpToDate::check],
            msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

        },
        "blocks when info about latest version can't be fetched"
    );

    is(
        $blockers->_check_single_blocker('UpToDate'),
        {
            id  => q[Elevate::Blockers::UpToDate::check],
            msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

        },
        "blocks when the installed script isn't the latest release"
    );

    $script_mock->unmock('_build_latest_version');
}

done_testing();
