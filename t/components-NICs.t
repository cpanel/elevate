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

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $nics = bless {}, 'Elevate::Components::NICs';

{
    note "checking pre_distro_upgrade";

    my $mock_nics = Test::MockModule->new('Elevate::NICs');
    $mock_nics->redefine(
        get_nics => sub { return ('eth0'); },
    );

    is( $nics->_rename_nics(), undef, '_rename_nics is a noop when there are not multiple nics' );

    $mock_nics->redefine(
        get_nics => sub { return ( 'eth0', 'eth1', 'eth2' ); },
    );

    my $mock_persistent_rules_path = Test::MockFile->file('/etc/udev/rules.d/70-persistent-net.rules');

    my @mocked_old_ifcfg_files;
    my @mocked_new_ifcfg_files;
    for my $i ( 0 .. 2 ) {
        my $mock_ifcfg_old = Test::MockFile->file("/etc/sysconfig/network-scripts/ifcfg-eth$i");
        push @mocked_old_ifcfg_files, $mock_ifcfg_old;

        my $mock_ifcfg_new = Test::MockFile->file("/etc/sysconfig/network-scripts/ifcfg-cpeth$i");
        push @mocked_new_ifcfg_files, $mock_ifcfg_new;
    }

    like(
        dies { $nics->_rename_nics() },
        qr/The file for the network interface card \(NIC\) using kernel-name \(eth0\) does\nnot exist/,
        'Dies when the expected network config file does not exist'
    );

    @mocked_old_ifcfg_files = ();
    @mocked_new_ifcfg_files = ();
    for my $i ( 0 .. 2 ) {
        my $mock_ifcfg_old = Test::MockFile->file( "/etc/sysconfig/network-scripts/ifcfg-eth$i", "this\nis\nnot\nvalid\nsyntax" );
        push @mocked_old_ifcfg_files, $mock_ifcfg_old;

        my $mock_ifcfg_new = Test::MockFile->file("/etc/sysconfig/network-scripts/ifcfg-cpeth$i");
        push @mocked_new_ifcfg_files, $mock_ifcfg_new;
    }

    like(
        dies { $nics->_rename_nics() },
        qr/Unable to rename eth0 to cpeth0/,
        'Dies when the ifcfg file does not contains the expected line'
    );
    message_seen( 'INFO', "Renaming eth0 to cpeth0" );

    @mocked_old_ifcfg_files = ();
    @mocked_new_ifcfg_files = ();
    for my $i ( 0 .. 2 ) {
        my $mock_ifcfg_old = Test::MockFile->file( "/etc/sysconfig/network-scripts/ifcfg-eth$i", "DEVICE=eth$i" );
        push @mocked_old_ifcfg_files, $mock_ifcfg_old;

        my $mock_ifcfg_new = Test::MockFile->file("/etc/sysconfig/network-scripts/ifcfg-cpeth$i");
        push @mocked_new_ifcfg_files, $mock_ifcfg_new;
    }

    $nics->_rename_nics();

    for my $i ( 0 .. 2 ) {

        is(
            $mocked_new_ifcfg_files[$i]->contents(),
            "DEVICE=cpeth$i",
            'The new ifcfg file contains the expected contents'
        );

        message_seen( 'INFO', "Renaming eth$i to cpeth$i" );
    }

    @mocked_old_ifcfg_files = ();
    @mocked_new_ifcfg_files = ();
    for my $i ( 0 .. 2 ) {
        my $mock_ifcfg_old = Test::MockFile->file( "/etc/sysconfig/network-scripts/ifcfg-eth$i", "DEVICE=eth$i" );
        push @mocked_old_ifcfg_files, $mock_ifcfg_old;

        my $mock_ifcfg_new = Test::MockFile->file("/etc/sysconfig/network-scripts/ifcfg-cpeth$i");
        push @mocked_new_ifcfg_files, $mock_ifcfg_new;
    }

    open( my $w_fh, '>', '/etc/udev/rules.d/70-persistent-net.rules' );
    print $w_fh q[SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="fa:16:3e:48:13:b7", NAME="eth0"\nSUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="fa:16:3e:48:13:42", NAME="eth1"\n];
    close $w_fh;

    $nics->_rename_nics();

    for my $i ( 0 .. 2 ) {

        is(
            $mocked_new_ifcfg_files[$i]->contents(),
            "DEVICE=cpeth$i",
            'The new ifcfg file contains the expected contents'
        );

        message_seen( 'INFO', "Renaming eth$i to cpeth$i" );
    }

    like(
        $mock_persistent_rules_path->contents(),
        qr/NAME="cpeth0".*NAME="cpeth1"/,
        '70-persistent-net.rules gets updated when it exists'
    );

    no_messages_seen();
}

done_testing();
