#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - ./t/blockers.t                          Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

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
$mock_pkgr->redefine( 'is_installed' => 0 );

ok !cpev::_use_jetbackup4_or_earlier(), "JetBackup is not installed";

$mock_pkgr->redefine( 'is_installed' => 1 );

$mock_pkgr->redefine( 'get_package_version' => '3.2' );
ok cpev::_use_jetbackup4_or_earlier(), "JetBackup 3.2 is installed";

$mock_pkgr->redefine( 'get_package_version' => '4.0' );
ok cpev::_use_jetbackup4_or_earlier(), "JetBackup 4.0 is installed";

$mock_pkgr->redefine( 'get_package_version' => '5.1' );
ok !cpev::_use_jetbackup4_or_earlier(), "JetBackup 5.1 is installed";

$mock_pkgr->redefine( 'get_package_version' => '10' );
ok !cpev::_use_jetbackup4_or_earlier(), "JetBackup 10 is installed";

$mock_pkgr->redefine( 'get_package_version' => '44.1' );
ok !cpev::_use_jetbackup4_or_earlier(), "JetBackup 44.1 is installed";

done_testing();
