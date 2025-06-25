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

my %os_hash = (
    alma   => [8],
    cent   => [7],
    cloud  => [ 7, 8 ],
    ubuntu => [20],
);

note "checking _use_jetbackup4_or_earlier";

my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');

my $cpev = cpev->new;
my $jb   = $cpev->get_blocker('JetBackup');

{
    note "_use_jetbackup4_or_earlier";

    $mock_pkgr->redefine( 'is_installed' => 0 );
    ok( !$jb->_use_jetbackup4_or_earlier(), "JetBackup is not installed" );

    $mock_pkgr->redefine( 'is_installed' => 1 );

    $mock_pkgr->redefine( 'get_package_version' => '3.2' );
    ok $jb->_use_jetbackup4_or_earlier(), "JetBackup 3.2 is installed";

    $mock_pkgr->redefine( 'get_package_version' => '4.0' );
    ok $jb->_use_jetbackup4_or_earlier(), "JetBackup 4.0 is installed";

    $mock_pkgr->redefine( 'get_package_version' => '5.1' );
    ok !$jb->_use_jetbackup4_or_earlier(), "JetBackup 5.1 is installed";

    $mock_pkgr->redefine( 'get_package_version' => '10' );
    ok !$jb->_use_jetbackup4_or_earlier(), "JetBackup 10 is installed";

    $mock_pkgr->redefine( 'get_package_version' => '44.1' );
    ok !$jb->_use_jetbackup4_or_earlier(), "JetBackup 44.1 is installed";
}

{
    note "Jetbackup 4";

    my $jb_mock = Test::MockModule->new('Elevate::Components::JetBackup');

    foreach my $distro ( keys %os_hash ) {
        next if $distro eq 'ubuntu';
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $expected_target_os = Elevate::OS::upgrade_to_pretty_name();

            $jb_mock->redefine( '_use_jetbackup4_or_earlier' => 1 );
            is(
                $jb->_blocker_old_jetbackup(),
                {
                    id  => q[Elevate::Components::JetBackup::_blocker_old_jetbackup],
                    msg => "$expected_target_os does not support JetBackup prior to version 5.\nPlease upgrade JetBackup before elevate.\n",
                },
                q{Block if jetbackup 4 is installed.}
            );

            $jb_mock->redefine( '_use_jetbackup4_or_earlier' => 0 );
            is( $jb->_blocker_old_jetbackup(), 0, 'ok when jetbackup 4 or earlier is not installed.' );
        }
    }

}

{
    note 'Blocker Jetbackup is supported';

    my $jb_mock = Test::MockModule->new('Elevate::Components::JetBackup');

    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $expected_target_os = Elevate::OS::upgrade_to_pretty_name();
            is( $jb->_blocker_jetbackup_is_supported(), undef, "JetBackup is supported for upgrades to $expected_target_os" );
        }
    }
}

done_testing();
