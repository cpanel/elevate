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

my $cpev_mock   = Test::MockModule->new('cpev');
my $script_mock = Test::MockModule->new('Elevate::Script');

my $cpev   = cpev->new;
my $script = $cpev->get_blocker('ElevateScript');

{
    $0 = '/root/elevate-cpanel';
    is(
        $script->_blocker_wrong_location(),
        {
            id  => q[Elevate::Blockers::ElevateScript::_blocker_wrong_location],
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{We need elevate-cpanel to live in /scripts/}
    );

    $0 = '';
    is(
        $script->_blocker_wrong_location(),
        {
            id  => q[Elevate::Blockers::ElevateScript::_blocker_wrong_location],
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{Handle if \$0 is broken.}
    );

    $0 = '/scripts/elevate-cpanel';
    is( $script->_blocker_wrong_location(), 0, "\$0 can be /scripts/" );
    $0 = '/usr/local/cpanel/scripts/elevate-cpanel';
    is( $script->_blocker_wrong_location(), 0, "\$0 can be /usr/local/cpanel/scripts/" );
}

{
    note "checking script update check";

    $script_mock->redefine( '_build_latest_version' => sub { return undef } );

    my $blockers = Elevate::Blockers->new( cpev => $cpev );

    local $0 = '/scripts/elevate-cpanel';

    $blockers->_check_single_blocker('ElevateScript'),

      is(
        $blockers->blockers,
        [
            {
                id  => q[Elevate::Blockers::ElevateScript::_is_up_to_date],
                msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

            }
        ],
        "blocks when info about latest version can't be fetched"
      );

    $blockers->blockers( [] );
    $blockers->_check_single_blocker('ElevateScript'),

      is(
        $blockers->blockers,
        [
            {
                id  => q[Elevate::Blockers::ElevateScript::_is_up_to_date],
                msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

            }
        ],
        "blocks when the installed script isn't the latest release"
      );

    $script_mock->unmock('_build_latest_version');
}

done_testing();
