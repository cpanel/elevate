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

    set_os_to_centos_7();

    my $mock_nics = Test::MockModule->new('Elevate::Components::NICs');
    $mock_nics->redefine(
        get_nics => sub { return ('eth0'); },
    );

    is( $nics->_rename_eth_devices(), undef, '_rename_eth_devices is a noop when there are not multiple nics' );

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
        dies { $nics->_rename_eth_devices() },
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
        dies { $nics->_rename_eth_devices() },
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

    $nics->_rename_eth_devices();

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

    $nics->_rename_eth_devices();

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
    note "testing check method";

    my $nics_mock = Test::MockModule->new('Elevate::Components::NICs');
    $nics_mock->redefine(
        _blocker_missing_sbin_ip => sub { die "do not call this\n"; },
    );

    for my $version (qw{ 20 22}) {
        set_os_to( 'ubuntu', $version );
        try_ok { $nics->check() } "Short-circuits for upgrades that do not need leapp";
    }

    set_os_to_centos_7();

    my $cpev_mock = Test::MockModule->new('cpev');
    $cpev_mock->redefine(
        upgrade_distro_manually => 1,
    );

    try_ok { $nics->check() } "Short-circuits for manual upgrades";
}

{
    note 'Test _blocker_missing_sbin_ip';

    my $sbin_ip = Test::MockFile->file('/sbin/ip');
    like(
        $nics->_blocker_missing_sbin_ip(),
        {
            id  => q[Elevate::Components::NICs::_blocker_missing_sbin_ip],
            msg => q[Missing /sbin/ip binary],
        },
        '/sbin/ip does not exist',
    );

    $sbin_ip->contents('cool');
    like(
        $nics->_blocker_missing_sbin_ip(),
        {
            id  => q[Elevate::Components::NICs::_blocker_missing_sbin_ip],
            msg => q[Missing /sbin/ip binary],
        },
        '/sbin/ip is not executable',
    );

    chmod 755, $sbin_ip->path();
    is( $nics->_blocker_missing_sbin_ip(), undef, 'No blocker when /sbin/ip is executable' );
}

{
    note 'Testing _blocker_bad_nics_naming';

    my $cpev_mock = Test::MockModule->new('cpev');
    my $nics_mock = Test::MockModule->new('Elevate::Components::NICs');
    $nics_mock->redefine(
        get_eths => sub { die "do not call this yet\n"; },
    );

    set_os_to_almalinux_9();
    try_ok { $nics->_nics_have_missing_ifcfg_files() } "Short-circuits for upgrades that do not support network scripts";

    $nics_mock->unmock('get_eths');

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

    my %os_hash = (
        cent => 7,
        alma => 8,
    );
    foreach my $distro ( sort keys %os_hash ) {
        set_os_to( $distro, $os_hash{$distro} );

        my $sbin_ip    = Test::MockFile->file('/sbin/ip');
        my $ifcfg_eth0 = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth0', 'mocked' );
        my $ifcfg_eth1 = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth1', 'mocked' );

        # Mock all necessary file access
        my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');
        $errors_mock->redefine( 'saferunnoerror' => '' );
        $sbin_ip->contents('');
        chmod 755, $sbin_ip->path();

        $nics_mock->redefine( 'get_nics' => sub { qw< eth0 eth1 > } );
        $user_consent = 0;
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
    }
}

{
    note 'Testing _nics_have_missing_ifcfg_files';

    my $nics_mock = Test::MockModule->new('Elevate::Components::NICs');
    $nics_mock->redefine( get_nics => sub { die "do not call this yet\n"; } );

    set_os_to_almalinux_9();
    try_ok { $nics->_nics_have_missing_ifcfg_files() } "Short-circuits for upgrades that do not support network scripts";

    $nics_mock->redefine( 'get_nics' => sub { qw< eth0 eth1 > } );

    my %os_hash = (
        cent => 7,
        alma => 8,
    );
    foreach my $distro ( keys %os_hash ) {
        set_os_to( $distro, $os_hash{$distro} );

        my $ifcfg_eth0 = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth0', 'mocked' );
        my $ifcfg_eth1 = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth1', 'mocked' );

        is( $nics->_nics_have_missing_ifcfg_files(), undef, 'No blocker when all of the ifcfg files exist and have size' );

        unlink '/etc/sysconfig/network-scripts/ifcfg-eth1';
        like(
            $nics->_nics_have_missing_ifcfg_files(),
            {
                id  => q[Elevate::Components::NICs::_nics_have_missing_ifcfg_files],
                msg => qr/This script is unable to rename the following network interface cards\ndue to a missing ifcfg file/,
            },
            'Blocker when the ifcfg does not exist'
        );
    }
}

{
    note 'Testing _blocker_ifcfg_files_missing_type_parameter';

    my $mock_nic_component = Test::MockModule->new('Elevate::Components::NICs');
    my $mock_file_slurper  = Test::MockModule->new('File::Slurper');

    my %os_hash = (
        cent   => [7],
        ubuntu => [20],
    );
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_nic_component->redefine(
                get_nics => sub { die "DO NOT CALL THIS\n"; },
            );

            ok( lives { $nics->_blocker_ifcfg_files_missing_type_parameter() }, "This check is a noop for $distro $version" );
        }
    }

    set_os_to( 'alma', 8 );

    $mock_nic_component->redefine(
        get_nics => sub { return ('eth0'); },
    );

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

    is( $nics->_blocker_ifcfg_files_missing_type_parameter(), undef, 'No blocker when the TYPE parameter is defined' );

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
        $nics->_blocker_ifcfg_files_missing_type_parameter(),
        {
            id  => 'Elevate::Components::NICs::_blocker_ifcfg_files_missing_type_parameter',
            msg => qr/The following network-scripts files are missing the TYPE key/,
        },
        'No blocker when the TYPE parameter is defined',
    );
}

{
    note 'Testing _blocker_has_ifcfg_files';

    my $mock_dir = Test::MockFile->dir('/etc/sysconfig/network-scripts');
    mkdir '/etc/sysconfig/network-scripts';

    my $mock_eth0           = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth0',   'mocked' );
    my $mock_eth0_secondary = Test::MockFile->file( '/etc/sysconfig/network-scripts/ifcfg-eth0:1', 'mocked' );

    my %os_hash = (
        cent => 7,
        alma => 8,
    );
    foreach my $distro ( sort keys %os_hash ) {
        set_os_to( $distro, $os_hash{$distro} );
        try_ok { $nics->_blocker_has_ifcfg_files() } "Short-circuits on servers where network scripts are supported";
    }

    set_os_to_almalinux_9();

    clear_messages_seen();

    like(
        $nics->_blocker_has_ifcfg_files(),
        {
            id  => 'Elevate::Components::NICs::_blocker_has_ifcfg_files',
            msg => qr/this machine has the following alias interfaces defined/,
        },
        'Blocker when alias interfaces are found',
    );

    message_seen( WARN  => qr/Your machine has network interface cards configured using the legacy/ );
    message_seen( ERROR => qr/this machine has the following alias interfaces defined/ );

    my $nics_mock = Test::MockModule->new('Elevate::Components::NICs');
    $nics_mock->redefine( is_check_mode => 1 );

    my $user_consent   = 0;
    my $mock_io_prompt = Test::MockModule->new('IO::Prompt');
    $mock_io_prompt->redefine(
        prompt => sub { return $user_consent; },
    );

    unlink '/etc/sysconfig/network-scripts/ifcfg-eth0:1';

    is( $nics->_blocker_has_ifcfg_files(), undef, 'No blocker if script is in check mode and no secondary interfaces are found' );

    message_seen( WARN => qr/Your machine has network interface cards configured using the legacy/ );
    message_seen( INFO => qr/the legacy network-scripts style configuration\nis no longer supported/ );

    $nics_mock->redefine( is_check_mode => 0 );

    like(
        $nics->_blocker_has_ifcfg_files(),
        {
            id  => 'Elevate::Components::NICs::_blocker_has_ifcfg_files',
            msg => qr/The system cannot be elevated to.*until the legacy network-scripts configuration/,
        },
        'Blocker when user does not consent to converting the network scripts to NetworkManager style configuration'
    );

    message_seen( WARN  => qr/Your machine has network interface cards configured using the legacy/ );
    message_seen( WARN  => qr/Prior to elevating this system to.*, this script will automatically/ );
    message_seen( ERROR => qr/The system cannot be elevated to.*until the legacy network-scripts configuration/ );

    $user_consent = 1;

    is( $nics->_blocker_has_ifcfg_files(), undef, 'No blocker if no secondary alias configurations are found and the user consents to us updating their configurations' );

    message_seen( WARN => qr/Your machine has network interface cards configured using the legacy/ );
    message_seen( WARN => qr/Prior to elevating this system to.*, this script will automatically/ );

    unlink '/etc/sysconfig/network-scripts/ifcfg-eth0';

    is( $nics->_blocker_has_ifcfg_files(), undef, 'No blocker if there are no ifcfg files on the system' );

    no_messages_seen();
}

{
    note 'Testing get_nics';

    set_os_to_centos_7();

    my @mock_files;
    for my $i ( 0 .. 2 ) {
        my $mock_path = Test::MockFile->symlink( "../../devices/pci0000:00/0000:00:03.0/virtio0/net/eth$i", "/sys/class/net/eth$i" );
        push @mock_files, $mock_path;
    }

    my $mock_lo = Test::MockFile->symlink( '../../devices/virtual/net/lo', '/sys/class/net/lo' );

    my ( $nic0, $nic1, $nic2 );
    my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Errors');
    $mock_saferun->redefine(
        saferunnoerror => sub { return sbin_ip_output( $nic0, $nic1, $nic2 ); },
    );

    $nic0 = 'lo';
    $nic1 = 'lo';
    $nic2 = 'lo';
    my @nics = $nics->get_nics();
    is(
        \@nics,
        [],
        'Returns expected nics',
    );

    $nic1 = 'eth0';
    @nics = $nics->get_nics();
    is(
        \@nics,
        ['eth0'],
        'Returns expected nics',
    );

    $nic2 = 'eth1';
    @nics = $nics->get_nics();
    is(
        \@nics,
        [ 'eth0', 'eth1' ],
        'Returns expected nics',
    );

    $nic0 = 'eth0';
    $nic1 = 'eth1';
    $nic2 = 'eth2';
    @nics = $nics->get_nics();
    is(
        \@nics,
        [ 'eth0', 'eth1', 'eth2' ],
        'Returns expected nics',
    );
}

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
