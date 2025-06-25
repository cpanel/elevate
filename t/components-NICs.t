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

my $nics = cpev->new->get_component('NICs');

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

{
    note "testing checks method";

    my $cpev_mock = Test::MockModule->new('cpev');
    my $nics_mock = Test::MockModule->new('Elevate::NICs');

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
            id  => q[Elevate::Components::NICs::_blocker_bad_nics_naming],
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
            id  => q[Elevate::Components::NICs::_blocker_bad_nics_naming],
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
            id  => q[Elevate::Components::NICs::_nics_have_missing_ifcfg_files],
            msg => qr/This script is unable to rename the following network interface cards\ndue to a missing ifcfg file/,
        },
        'Blocker when the ifcfg does not exist'
    );
}

{
    note 'Testing _blocker_ifcfg_files';

    my $mock_nics          = Test::MockModule->new('Elevate::NICs');
    my $mock_nic_component = Test::MockModule->new('Elevate::Components::NICs');
    my $mock_file_slurper  = Test::MockModule->new('File::Slurper');

    my %os_hash = (
        cent   => [7],
        ubuntu => [20],
    );
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_nics->redefine(
                get_nics => sub { die "DO NOT CALL THIS\n"; },
            );

            ok( lives { $nics->_blocker_ifcfg_files() }, "This check is a noop for $distro $version" );
        }
    }

    set_os_to( 'alma', 8 );

    $mock_nics->redefine(
        get_nics => sub { return ('eth0'); },
    );

    $mock_nic_component->redefine(
        _nics_have_missing_ifcfg_files => 1,
    );

    $mock_file_slurper->redefine(
        read_binary => sub { die "DO NOT CALL THIS\n"; },
    );

    ok( lives { $nics->_blocker_ifcfg_files() }, 'Returns early if the ifcfg file is missing' );

    $mock_nic_component->redefine(
        _nics_have_missing_ifcfg_files => 0,
    );

    my $mock_contents;
    $mock_file_slurper->redefine(
        read_binary => sub { return $mock_contents; },
    );

    $mock_contents = <<~'EOS';
    BOOTPROTO=dhcp
    DEVICE=ens3
    DHCLIENT_SET_DEFAULT_ROUTE=no
    HWADDR=fa:16:3e:48:13:b7
    IPV6INIT=yes
    IPV6_AUTOCONF=yes
    MTU=1500
    ONBOOT=yes
    TYPE=Ethernet
    USERCTL=no
    EOS

    is( $nics->_blocker_ifcfg_files(), undef, 'No blocker when the TYPE parameter is defined' );

    $mock_contents = <<~'EOS';
    BOOTPROTO=dhcp
    DEVICE=ens3
    DHCLIENT_SET_DEFAULT_ROUTE=no
    HWADDR=fa:16:3e:48:13:b7
    IPV6INIT=yes
    IPV6_AUTOCONF=yes
    MTU=1500
    ONBOOT=yes
    USERCTL=no
    EOS

    like(
        $nics->_blocker_ifcfg_files(),
        {
            id  => 'Elevate::Components::NICs::_blocker_ifcfg_files',
            msg => qr/The following network-scripts files are missing the TYPE key/,
        },
        'No blocker when the TYPE parameter is defined',
    );
}

done_testing();
