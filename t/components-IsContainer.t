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

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib", $FindBin::Bin . "/../lib";
use Test::Elevate;

use Elevate::Components::IsContainer ();

use cPstrict;

my $mock = Test::MockModule->new('Elevate::Components::IsContainer');
{
    note "containers";

    my $isContainer = cpev->new->get_component('IsContainer');

    $mock->redefine( '_is_container_envtype' => 1 );

    my $cpev = cpev->new();
    my $msg  = <<~'EOS';
    cPanel thinks that this is a container-like environment.
    This cannot be upgraded by this script.
    Consider contacting your hypervisor provider for alternative solutions.
    EOS

    is(
        $isContainer->check(),
        {
            id  => q[Elevate::Components::IsContainer::check],
            msg => $msg,
        },
        q{Block if this is a container like environment.}

    );

    $mock->redefine( '_is_container_envtype' => 0 );
    is( $isContainer->check(), 0, q[not a container.] );
}

done_testing;
