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

use Test::MockFile 0.032 qw{nostrict};
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $cpev_mock   = Test::MockModule->new('cpev');
my $script_mock = Test::MockModule->new('Elevate::Script');

my $cpev   = cpev->new;
my $script = $cpev->get_blocker('ElevateScript');

{
    local $0 = '/root/elevate-cpanel';
    is(
        $script->_blocker_wrong_location(),
        {
            id  => q[Elevate::Components::ElevateScript::_blocker_wrong_location],
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{We need elevate-cpanel to live in /scripts/}
    );

    local $0 = '';
    is(
        $script->_blocker_wrong_location(),
        {
            id  => q[Elevate::Components::ElevateScript::_blocker_wrong_location],
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{Handle if \$0 is broken.}
    );

    # Cwd::abs_path will return undef if the file doesn't exist
  SKIP: {
        skip "/scripts does not exist on this host, assertion will fail due to Cwd::abs_path returning undef in that case", 1 if ( !-d '/scripts' );
        local $0 = '/scripts/elevate-cpanel';
        is( $script->_blocker_wrong_location(), 0, "\$0 can be /scripts/" ) || diag explain $script->_blocker_wrong_location();
    }
    local $0 = '/usr/local/cpanel/scripts/elevate-cpanel';
    is( $script->_blocker_wrong_location(), 0, "\$0 can be /usr/local/cpanel/scripts/" );
}

{
    note "checking script update check";

    $script_mock->redefine( '_build_latest_version' => sub { return undef } );

    my $components = Elevate::Components->new( cpev => $cpev );

    local $0 = '/scripts/elevate-cpanel';

    $components->_check_single_blocker('ElevateScript'),

      is(
        $components->blockers,
        bag {
            item {
                id  => q[Elevate::Components::ElevateScript::_is_up_to_date],
                msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

            };
            etc;
        },
        "blocks when info about latest version can't be fetched"
      );

    $components->blockers( [] );
    $components->_check_single_blocker('ElevateScript'),

      is(
        $components->blockers,
        bag {
            item {
                id  => q[Elevate::Components::ElevateScript::_is_up_to_date],
                msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

            };
            etc;
        },
        "blocks when the installed script isn't the latest release"
      );

    $script_mock->unmock('_build_latest_version');
}

done_testing();
