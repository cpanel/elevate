#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::nics;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use cPstrict;

my @mock_files;
for my $i ( 0 .. 2 ) {
    my $mock_path = Test::MockFile->symlink( '/virtual', "/sys/class/net/eth$i" );
    push @mock_files, $mock_path;
}

my ( $nic0, $nic1, $nic2 );
my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Errors');
$mock_saferun->redefine(
    saferunnoerror => sub { return sbin_ip_output( $nic0, $nic1, $nic2 ); },
);

$nic0 = 'lo';
$nic1 = 'lo';
$nic2 = 'lo';
my @nics = Elevate::NICs::get_nics();
is(
    \@nics,
    [],
    'Returns expected nics',
);

$nic1 = 'eth0';
@nics = Elevate::NICs::get_nics();
is(
    \@nics,
    ['eth0'],
    'Returns expected nics',
);

$nic2 = 'eth1';
@nics = Elevate::NICs::get_nics();
is(
    \@nics,
    [ 'eth0', 'eth1' ],
    'Returns expected nics',
);

$nic0 = 'eth0';
$nic1 = 'eth1';
$nic2 = 'eth2';
@nics = Elevate::NICs::get_nics();
is(
    \@nics,
    [ 'eth0', 'eth1', 'eth2' ],
    'Returns expected nics',
);

sub sbin_ip_output ( $nic0 = undef, $nic1 = undef, $nic2 = undef ) {
    my $out = <<"EOS";
1: $nic0: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: $nic1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether 46:6b:ce:04:98:99 brd ff:ff:ff:ff:ff:ff
    inet 137.184.225.139/20 brd 137.184.239.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet 10.48.0.6/16 brd 10.48.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::446b:ceff:fe04:9899/64 scope link
       valid_lft forever preferred_lft forever
3: $nic2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether ea:b0:b6:c9:51:ea brd ff:ff:ff:ff:ff:ff
    inet 10.124.0.3/20 brd 10.124.15.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::e8b0:b6ff:fec9:51ea/64 scope link
       valid_lft forever preferred_lft forever
EOS

    return $out;
}

done_testing();
