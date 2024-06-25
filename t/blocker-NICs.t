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
my $nics_mock = Test::MockModule->new('Elevate::NICs');

my $cpev = cpev->new;
my $nics = $cpev->get_blocker('NICs');

my $user_consent   = 0;
my $mock_io_prompt = Test::MockModule->new('IO::Prompt');
$mock_io_prompt->redefine(
    prompt => sub { return $user_consent; },
);

## Make sure we have NICs that would fail
#my $mock_ip_addr = q{1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
#    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
#    inet 127.0.0.1/8 scope host lo
#       valid_lft forever preferred_lft forever
#    inet6 ::1/128 scope host
#       valid_lft forever preferred_lft forever
#2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
#    link/ether fa:16:3e:98:ea:8d brd ff:ff:ff:ff:ff:ff
#    inet 10.2.67.134/19 brd 10.2.95.255 scope global dynamic eth0
#       valid_lft 28733sec preferred_lft 28733sec
#    inet6 2620:0:28a4:4140:f816:3eff:fe98:ea8d/64 scope global mngtmpaddr dynamic
#       valid_lft 2591978sec preferred_lft 604778sec
#    inet6 fe80::f816:3eff:fe98:ea8d/64 scope link
#       valid_lft forever preferred_lft forever
#3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
#    link/ether fa:16:3e:98:ea:8d brd ff:ff:ff:ff:ff:ff
#    inet 10.2.67.135/19 brd 10.2.95.255 scope global dynamic eth0
#       valid_lft 28733sec preferred_lft 28733sec
#    inet6 2620:0:28a4:4140:f816:3eff:fe98:ea8d/64 scope global mngtmpaddr dynamic
#       valid_lft 2591978sec preferred_lft 604778sec
#    inet6 fe80::f816:3eff:fe98:ea8d/64 scope link
#       valid_lft forever preferred_lft forever
#};

{
    # The NICs blocker runs /sbin/ip which breaks because Cpanel::SafeRun::Simple
    # opens /dev/null which Test::MockFile does not mock and is annoyed by it

    my $sbin_ip    = Test::MockFile->file('/sbin/ip');
    my $ifcfg_eth0 = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth0', 'mocked' );
    my $ifcfg_eth1 = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth1', 'mocked' );
    note "checking kernel-named NICs";

    # what happens if /sbin/ip is not available
    is(
        $nics->_blocker_bad_nics_naming(),
        {
            id  => q[Elevate::Blockers::NICs::_blocker_bad_nics_naming],
            msg => 'Missing /sbin/ip binary',
        },
        q{What happens when /sbin/ip is not available}
    );

    # Mock all necessary file access
    my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');
    $errors_mock->redefine( 'saferunnoerror' => '' );
    $sbin_ip->contents('');
    chmod 755, $sbin_ip->path();

    $nics_mock->redefine( 'get_nics' => sub { qw< eth0 eth1 > } );
    like(
        $nics->_blocker_bad_nics_naming(),
        {
            id  => q[Elevate::Blockers::NICs::_blocker_bad_nics_naming],
            msg => qr/To have this script perform the upgrade/,
        },
        q{What happens when ip addr returns eth0 and eth1}
    );

    $user_consent = 1;
    is(
        $nics->_blocker_bad_nics_naming(),
        0,
        'No blocker when the user consents to the script renaming the NICs'
    );

    $nics_mock->redefine( 'get_nics' => sub { qw< w0p1lan > } );
    $errors_mock->redefine(
        'saferunnoerror' => sub {
            $_[0] eq '/sbin/ip' ? '' : $errors_mock->original('saferunnoerror');
        }
    );

    is( $nics->_blocker_bad_nics_naming(), 0, "No blocker with w0p1lan ethernet card" );

    unlink '/etc/sysconfig/network-scripts/ifcfg-eth1';
    like(
        $nics->_nics_have_missing_ifcfg_files( 'eth0', 'eth1' ),
        {
            id  => q[Elevate::Blockers::NICs::_nics_have_missing_ifcfg_files],
            msg => qr/This script is unable to rename the following network interface cards\ndue to a missing ifcfg file/,
        },
        'Blocker when the ifcfg does not exist'
    );
}

done_testing();
