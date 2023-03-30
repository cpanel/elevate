#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib", $FindBin::Bin . "/../lib";
use Test::Elevate;

use Elevate::Blockers::IsContainer ();

use cPstrict;

my $mock = Test::MockModule->new('Elevate::Blockers::IsContainer');
{
    note "containers";

    $mock->redefine( '_is_container_envtype' => 1 );

    #my $cpev = bless { _abort_on_first_blocker => 1 }, 'cpev';
    my $cpev = cpev->new( _abort_on_first_blocker => 1 );
    is(
        dies { Elevate::Blockers::IsContainer::check($cpev) },
        {
            id  => 90,
            msg => "cPanel thinks that this is a container-like environment, which this script cannot support at this time.",
        },
        q{Block if this is a container like environment.}
    );

    $mock->redefine( '_is_container_envtype' => 0 );
    is( Elevate::Blockers::IsContainer::check($cpev), 0, q[not a container.] );
}

done_testing;
