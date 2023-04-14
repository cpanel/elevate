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

my $cpev_mock   = Test::MockModule->new('cpev');
my $script_mock = Test::MockModule->new('Elevate::Blockers::Script');

my $cpev   = cpev->new;
my $script = $cpev->get_blocker('Script');

{
    $0 = '/root/elevate-cpanel';
    is(
        $script->_blocker_wrong_location(),
        {
            id  => q[Elevate::Blockers::Script::_blocker_wrong_location],
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{We need elevate-cpanel to live in /scripts/}
    );

    $0 = '';
    is(
        $script->_blocker_wrong_location(),
        {
            id  => q[Elevate::Blockers::Script::_blocker_wrong_location],
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{Handle if \$0 is broken.}
    );

    $0 = '/scripts/elevate-cpanel';
    is( $script->_blocker_wrong_location(), 0, "\$0 can be /scripts/" );
    $0 = '/usr/local/cpanel/scripts/elevate-cpanel';
    is( $script->_blocker_wrong_location(), 0, "\$0 can be /usr/local/cpanel/scripts/" );
}

done_testing();
