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

    my $jb_mock = Test::MockModule->new('Elevate::Blockers::JetBackup');

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';

        $jb_mock->redefine( '_use_jetbackup4_or_earlier' => 1 );
        is(
            $jb->_blocker_old_jetbackup(),
            {
                id  => q[Elevate::Blockers::JetBackup::_blocker_old_jetbackup],
                msg => "$expected_target_os does not support JetBackup prior to version 5.\nPlease upgrade JetBackup before elevate.\n",
            },
            q{Block if jetbackup 4 is installed.}
        );

        $jb_mock->redefine( '_use_jetbackup4_or_earlier' => 0 );
        is( $jb->_blocker_old_jetbackup(), 0, 'ok when jetbackup 4 or earlier is not installed.' );
    }

}

done_testing();
