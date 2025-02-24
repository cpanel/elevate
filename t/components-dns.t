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

my $cpev_mock = Test::MockModule->new('cpev');
my $dns_mock  = Test::MockModule->new('Elevate::Components::DNS');

my $cpconf;
my $conf_mock = Test::MockModule->new('Cpanel::Config::LoadCpConf');
$conf_mock->redefine(
    loadcpconf => sub { return $cpconf; },
);

my $cpev = cpev->new;
my $dns  = $cpev->get_blocker('DNS');

{
    for my $os ( 'cent', 'cloud', 'ubuntu', 'alma' ) {
        set_os_to($os);
        my $expected_target_os = Elevate::OS::upgrade_to_pretty_name();
        $cpconf = { 'local_nameserver_type' => 'nsd' };
        like(
            $dns->check(),
            {
                id  => q[Elevate::Components::DNS::_blocker_nameserver_not_supported],
                msg => qr/^$expected_target_os only supports the following nameservers:/
            },
            'nsd nameserver is a blocker.'
        );

        $cpconf = { 'local_nameserver_type' => 'mydns' };
        like(
            $dns->check(),
            {
                id  => q[Elevate::Components::DNS::_blocker_nameserver_not_supported],
                msg => qr/^$expected_target_os only supports the following nameservers:/
            },
            'mydns nameserver is a blocker.'
        );

        $cpconf = {};
        is( $dns->check(), 0, "Nothing set, we're ok" );
        $cpconf = { 'local_nameserver_type' => 'powerdns' };
        is( $dns->check(), 0, "if they use powerdns, we're ok" );
        $cpconf = { 'local_nameserver_type' => 'disabled' };
        is( $dns->check(), 0, "if they use no dns, we're ok" );
    }

    for my $os ( 'cent', 'cloud', 'alma' ) {
        set_os_to($os);
        $cpconf = { 'local_nameserver_type' => 'bind' };
        is( $dns->check(), 0, "if they use bind, we're ok" );
    }

    set_os_to('ubuntu');
    my $expected_target_os = Elevate::OS::upgrade_to_pretty_name();
    $cpconf = { 'local_nameserver_type' => 'bind' };
    like(
        $dns->check(),
        {
            id  => q[Elevate::Components::DNS::_blocker_nameserver_not_supported],
            msg => qr/^$expected_target_os only supports the following nameservers:/
        },
        "bind nameserver is a blocker for $expected_target_os."
    );
}

done_testing();
