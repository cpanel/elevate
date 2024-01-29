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

    my $blockers    = cpev->new->blockers;
    my $isContainer = $blockers->_get_blocker_for('IsContainer');

    $mock->redefine( '_is_container_envtype' => 1 );

    my $cpev = cpev->new();
    my $msg  = <<~'EOS';
    cPanel thinks that this is a container-like environment.
    This cannot be upgraded by the native leapp tool.
    Consider contacting your hypervisor provider for alternative solutions.
    EOS

    is(
        $isContainer->check(),
        {
            id  => q[Elevate::Blockers::IsContainer::check],
            msg => $msg,
        },
        q{Block if this is a container like environment.}

    );

    $mock->redefine( '_is_container_envtype' => 0 );
    is( $isContainer->check(), 0, q[not a container.] );
}

done_testing;
