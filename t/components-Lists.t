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
use Test2::Tools::Mock;

use Test::MockModule qw/strict/;
use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_stage_file = Test::MockFile->file( '/var/cpanel/elevate', '' );
my $mock_list_dir   = Test::MockFile->dir('/etc/apt/sources.list.d');

my $mock_pkgmgr = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
my $mock_comp   = Test::MockModule->new('Elevate::Components::Lists');

my $comp = cpev->new->get_component('Lists');

my %os_hash = (
    alma => [8],
    cent => [7],
);

{
    note 'Lists blockers';

    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );
            is( $comp->check(), 1, 'Returns early if the system does not use the apt package manager' );
            no_messages_seen();
        }
    }

    set_os_to( 'ubuntu', 20 );

    my $makecache_ret;
    my $clean_all_ret = {};
    my $showhold_ret  = {};
    $mock_pkgmgr->redefine(
        clean_all => sub { return $clean_all_ret; },
        makecache => sub { return $makecache_ret; },
        showhold  => sub { return $showhold_ret; },
    );

    $clean_all_ret = {
        status => 42,
        stderr => ['No soup for you'],
    };

    $makecache_ret = 'No soup for you';

    like(
        $comp->_blocker_apt_can_update(),
        {
            id  => q[Elevate::Components::Lists::AptUpdateError],
            msg => qr/Since this script relies heavily on apt, you will need to address this/,
        },
        'Returns a blocker when makecache fails'
    );

    message_seen( WARN  => qr/Errors encountered running 'apt-get clean'/ );
    message_seen( ERROR => qr/If you need assistance, open a ticket with cPanel Support, as outlined here:/ );
    message_seen( ERROR => 'No soup for you' );
    no_messages_seen();

    $clean_all_ret = {
        status => 0,
    };

    $makecache_ret = '';

    is( $comp->_blocker_apt_can_update(), undef, 'No blocker when makecache completes successfully' );
    no_messages_seen();

    $showhold_ret = {
        status => 42,
        stderr => ['No soup for you'],
    };

    like(
        $comp->_blocker_apt_has_held_packages(),
        {
            id  => q[Elevate::Components::Lists::_blocker_apt_has_held_packages],
            msg => qr/Since we are unable to reliably determine if any packages are being held back/,
        },
        'Blocker detected when apt-mark showhold fails to return cleanly'
    );

    $showhold_ret = {
        status => 0,
        stdout => [ 'finn', 'quinn', ],
    };

    like(
        $comp->_blocker_apt_has_held_packages(),
        {
            id  => q[Elevate::Components::Lists::_blocker_apt_has_held_packages],
            msg => qr/The following packages are currently held back/,
        },
        'Blocker detected when apt-mark showhold finds packages that are being held'
    );

    $showhold_ret = {
        status => 0,
        stdout => [],
    };

    is( $comp->_blocker_apt_has_held_packages(), undef, 'No blockers found when there are no held packages' );

    my $mock_bad_list_file   = Test::MockFile->file( '/etc/apt/sources.list.d/bad.list',            'whoops' );
    my $mock_known_list_file = Test::MockFile->file( '/etc/apt/sources.list.d/cpanel-plugins.list', 'yup yup' );

    like(
        $comp->_blocker_invalid_apt_lists(),
        {
            id  => q[Elevate::Components::Lists::_blocker_invalid_apt_lists],
            msg => qr{The following unsupported list files were found in /etc/apt/sources\.list\.d},
        },
        'Blocker found when an unknown list file exists',
    );

    unlink '/etc/apt/sources.list.d/bad.list';
    is( $comp->_blocker_invalid_apt_lists(), undef, 'No blocker found when only known lists are found' );
}

{
    note 'post_distro_upgrade';

    set_os_to( 'ubuntu', 20 );

    my $mock_repo_file         = Test::MockFile->file( '/etc/apt/sources.list.d/thing.repo',          '' );
    my $mock_known_list_file   = Test::MockFile->file( '/etc/apt/sources.list.d/cpanel-plugins.list', 'yup yup' );
    my $mock_another_list_file = Test::MockFile->file( '/etc/apt/sources.list.d/EA4.list',            'for the win' );

    my @called_for_file;
    $mock_comp->redefine(
        _update_list_file => sub { shift; push @called_for_file, @_; return; },
    );

    is( $comp->post_distro_upgrade(), undef, 'Returns undef' );
    is(
        \@called_for_file,
        [
            'EA4.list',
            'cpanel-plugins.list',
        ],
        'The expected list files were updated',
    );

    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            $mock_comp->redefine(
                update_list_files => sub { die "Do not call\n"; },
            );

            is( $comp->post_distro_upgrade(), undef, 'Returns early on systems that do not rely on apt' );
        }
    }
}

{
    note 'mysql.list is vetted for u22 -> u24 upgrades';

    set_os_to( 'ubuntu', 22 );
    clear_messages_seen();

    my $mysql_list      = '/etc/apt/sources.list.d/mysql.list';
    my $mock_mysql_list = Test::MockFile->file( $mysql_list, <<~'EOS' );
    # Use command 'dpkg-reconfigure mysql-apt-config' as root for modifications.
    deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-apt-config
    deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-8.0
    deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-tools
    #deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-tools-preview
    deb-src https://repo.mysql.com/apt/ubuntu/ jammy mysql-8.0
    EOS

    is( $comp->_blocker_invalid_apt_lists(), undef, 'mysql.list does not block an Ubuntu 22 elevation' );

    $mock_comp->unmock_all();

    is( $comp->_update_list_file('mysql.list'), undef, 'Returns undef' );

    # The enabled stanzas are asserted individually rather than against the whole
    # file: maint/perlpkg.static drops any line starting with '#' at column 0,
    # even inside a q{} string, so the packed script and lib/ disagree on the
    # commented out mysql-tools-preview line.
    my $contents = $mock_mysql_list->contents();

    foreach my $stanza (
        q{deb https://repo.mysql.com/apt/ubuntu/ noble mysql-apt-config},
        q{deb https://repo.mysql.com/apt/ubuntu/ noble mysql-8.0},
        q{deb https://repo.mysql.com/apt/ubuntu/ noble mysql-tools},
        q{deb-src https://repo.mysql.com/apt/ubuntu/ noble mysql-8.0},
    ) {
        like( $contents, qr/^\Q$stanza\E$/m, "mysql.list enables '$stanza'" );
    }

    unlike( $contents, qr/jammy/, 'mysql.list no longer points at the Ubuntu 22 (jammy) MySQL repo' );

    no_messages_seen();
}

done_testing();
