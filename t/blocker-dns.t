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

my $cpev_mock = Test::MockModule->new('cpev');
my $dns_mock  = Test::MockModule->new('Elevate::Blockers::DNS');

my $cpev = cpev->new;
my $dns  = $cpev->get_blocker('DNS');

{
    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);
        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';
        is(
            $dns->_blocker_non_bind_powerdns('nsd'),
            {
                id  => q[Elevate::Blockers::DNS::_blocker_non_bind_powerdns],
                msg => <<~"EOS",
    $expected_target_os only supports bind or powerdns. We suggest you switch to powerdns.
    Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
    EOS
            },
            'nsd nameserver is a blocker.'
        );

        is(
            $dns->_blocker_non_bind_powerdns('mydns'),
            {
                id  => q[Elevate::Blockers::DNS::_blocker_non_bind_powerdns],
                msg => <<~"EOS",
    $expected_target_os only supports bind or powerdns. We suggest you switch to powerdns.
    Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
    EOS
            },
            'mydns nameserver is a blocker.'
        );

        is( $dns->_blocker_non_bind_powerdns('bind'),     0, "if they use bind, we're ok" );
        is( $dns->_blocker_non_bind_powerdns('powerdns'), 0, "if they use powerdns, we're ok" );
        is( $dns->_blocker_non_bind_powerdns('disabled'), 0, "if they use no dns, we're ok" );
    }
}

done_testing();
