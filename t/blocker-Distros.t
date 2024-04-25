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

my $cpev_mock    = Test::MockModule->new('cpev');
my $distros_mock = Test::MockModule->new('Elevate::Blockers::Distros');

my $cpev    = cpev->new;
my $distros = $cpev->get_blocker('Distros');

{
    note "Distro supported checks.";
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    unmock_os();
    my $f   = Test::MockFile->symlink( 'linux|centos|6|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
    my $rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

    my $m_custom = Test::MockFile->file(q[/var/cpanel/caches/Cpanel-OS.custom]);

    like(
        dies { $distros->check() },
        qr/This script is only designed to upgrade the following OSs/,
        'C6 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    unmock_os();
    $f = Test::MockFile->symlink( 'linux|centos|8|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    like(
        dies { $distros->check() },
        qr/This script is only designed to upgrade the following OSs/,
        'C8 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    unmock_os();
    $f = Test::MockFile->symlink( 'linux|cloudlinux|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $distros->check(), 0, 'CL7 is supported.' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    unmock_os();
    $f = Test::MockFile->symlink( 'linux|centos|7|4|2009', '/var/cpanel/caches/Cpanel-OS' );
    like(
        $distros->check(),
        {
            id  => q[Elevate::Blockers::Distros::_blocker_is_old_centos7],
            msg => qr{You need to run CentOS 7.9 and later to upgrade AlmaLinux 8. You are currently using},
        },
        'Need at least CentOS 7.9.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    unmock_os();
    $f = Test::MockFile->symlink( 'linux|centos|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    $m_custom->contents('');
    is(
        $distros->check(),
        {
            id  => q[Elevate::Blockers::Distros::_blocker_is_experimental_os],
            msg => 'Experimental OS detected. This script only supports CentOS 7 upgrades',
        },
        'Custom OS is not supported.'
    );
    $m_custom->unlink;
    is( $distros->_blocker_is_experimental_os(),  0, "if not experimental, we're ok" );
    is( $distros->_blocker_os_is_not_supported(), 0, "now on a valid C7" );
    is( $distros->_blocker_is_old_centos7(),      0, "now on a up to date C7" );

    #no_messages_seen();
}

done_testing();
