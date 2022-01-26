#!/usr/local/cpanel/3rdparty/bin/perl

# cpanel - ./t/blockers.t                          Copyright 2022 cPanel, L.L.C.
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile qw/strict/;
use Test::MockModule qw/strict/;

use cPstrict;
require $FindBin::Bin . '/../elevate-cpanel';

my $cpev_mock = Test::MockModule->new('cpev');
my @messages_seen;
$cpev_mock->redefine( '_msg' => sub { my ( $type, $msg ) = @_; push @messages_seen, [ $type, $msg ]; return } );

{
    no warnings 'once';
    local $Cpanel::Version::Tiny::major_version;
    is( cpev::blockers_check(), 1, "no major_version means we're not cPanel?" );
    message_seen( 'ERROR', 'Invalid cPanel & WHM major_version' );

    $Cpanel::Version::Tiny::major_version = 98;
    is( cpev::blockers_check(), 2, "11.98 is unsupported for this script." );
    message_seen( 'ERROR', qr/This version 11\.\d+\.\d+\.\d+ does not support upgrades to AlmaLinux 8. Please upgrade to cPanel version 102 or better/a );
}

{
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    my $f   = Test::MockFile->symlink( 'linux|centos|6|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
    my $rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

    is( cpev::blockers_check(), 3, "C6 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|8|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( cpev::blockers_check(), 3, "C8 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|cloudlinux|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( cpev::blockers_check(), 3, "CL7 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|4|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( cpev::blockers_check(), 4, "Need at least CentOS 7.9." );
    message_seen( 'ERROR', 'You need to run CentOS 7.9 and later to upgrade AlmaLinux 8. You are currently using CentOS v7.4.2009' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $custom = Test::MockFile->file( '/var/cpanel/caches/Cpanel-OS.custom', '' );
    is( cpev::blockers_check(), 5, "Custom OS is not supported." );
    message_seen( 'ERROR', 'Experimental OS detected. This script only supports CentOS 7 upgrades' );
}

# Dev sandbox
my $custom = Test::MockFile->file('/var/cpanel/caches/Cpanel-OS.custom');
my $f      = Test::MockFile->file( '/var/cpanel/dev_sandbox', '' );
is( cpev::blockers_check(), 6, "Dev sandbox is a blocker.." );
message_seen( 'ERROR', 'Cannot elevate a sandbox...' );

$f->unlink;
my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
my %installed = ( 'cpanel-ccs-calendarserver' => 9.2, 'postgresql-server' => 9.2 );
$pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
$pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

is( cpev::blockers_check(), 7, "CCS Calendar Server is a no go." );
message_seen( 'ERROR', 'You have the cPanel Calendar Server installed. Upgrades with this server in place are not supported.' );
message_seen( 'WARN',  'Removal of this server can lead to data loss.' );

delete $installed{'cpanel-ccs-calendarserver'};
is( cpev::blockers_check(), 8, "Postgresql 9.2 won't upgrade well." );
message_seen( 'ERROR', "You have postgresql-server version 9.2 installed." );
message_seen( 'ERROR', "This is upgraded irreversably to version 10.0 when you switch to almalinux 8" );
message_seen( 'ERROR', "We recommend data backup and removal of all postgresql packages before upgrade to AlmaLinux 8." );
message_seen( 'ERROR', "To re-install postgresql 9 on AlmaLinux 8, you can run: `dnf -y module enable postgresql:9.6; dnf -y install postgresql-server`" );

$installed{'postgresql-server'} = '10.0';
is( cpev::blockers_check(), 8, "Postgresql 10 still is blocked." );
message_seen( 'ERROR', "You have postgresql-server version 10.0 installed." );
message_seen( 'ERROR', "We recommend data backup and removal of all postgresql packages before upgrade to AlmaLinux 8." );
%installed = ();

my $cpconf_mock = Test::MockModule->new('Cpanel::Config::LoadCpConf');
my %cpanel_conf = ( 'local_nameserver_type' => 'nsd', 'mysql-version' => '5.7' );
$cpconf_mock->redefine( 'loadcpconf' => sub { return \%cpanel_conf } );

is( cpev::blockers_check(), 9, "nsd blocks an upgrade to AlmaLinux 8" );
message_seen( 'ERROR', 'AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns' );
message_seen( 'ERROR', 'Before upgrading, we suggest you run: /scripts/setupnameserver powerdns' );

$cpanel_conf{'local_nameserver_type'} = 'mydns';
is( cpev::blockers_check(), 9, "mydns blocks an upgrade to AlmaLinux 8" );
message_seen( 'ERROR', 'AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns' );
message_seen( 'ERROR', 'Before upgrading, we suggest you run: /scripts/setupnameserver powerdns' );

$cpanel_conf{'local_nameserver_type'} = 'powerdns';
is( cpev::blockers_check(), 10, "the script location is incorrect." );
message_seen( 'ERROR', "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n" );

$0 = '/scripts/elevate-cpanel';
is( cpev::blockers_check(), 11, "the script location is correct but MySQL 5.7 is installed." );
message_seen(
    'ERROR',
    "You are using MySQL 5.7 community server.\nThis version is not available for AlmaLinux 8.\nYou first need to update your MySQL server to 8.0 or later.\n\nYou can update to version 8.0 using the following command:\n\n    /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=8.0\n\nOnce the MySQL upgrade is finished, you can then retry to elevate to AlmaLinux 8.\n"
);

$cpanel_conf{'mysql-version'} = '10.2';
$0 = '/usr/local/cpanel/scripts/elevate-cpanel';
is( cpev::blockers_check(), 12, "the script location is correct but MariaDB 10.2 is installed." );
message_seen(
    'ERROR',
    "You are using MariaDB server 10.2, this version is not available for AlmaLinux 8.\nYou first need to update MariaDB server to 10.3 or later.\n\nYou can update to version 10.3 using the following command:\n\n    /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.3\n\nOnce the MariaDB upgrade is finished, you can then retry to elevate to AlmaLinux 8.\n"
);

$cpanel_conf{'mysql-version'} = '4.0';
is( cpev::blockers_check(), 13, 'An Unknown MySQL is present so we block for now.' );
message_seen( 'ERROR', "We do not know how to upgrade to AlmaLinux 8 with MySQL version 4.0.\nPlease open a support ticket.\n" );

#my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
#$mock_saferun->redefine(
#    saferunnoerror => sub {
#        $saferun_output;
#    }
#);

done_testing();

sub mock_distro ( $distro, $major, $minor ) {

}

sub message_seen ( $type, $msg ) {
    my $line = shift @messages_seen;
    if ( ref $line ne 'ARRAY' ) {
        fail("    No message of type '$type' was emitted.");
        fail("    With output: $msg");
        return 0;
    }

    my $type_seen = $line->[0] // '';
    $type_seen =~ s/^\s+//;
    $type_seen =~ s/: //;

    is( $type_seen, $type, "  |_  Message type is $type" );
    if ( ref $msg eq 'Regexp' ) {
        like( $line->[1], $msg, "  |_  Message string is expected." );
    }
    else {
        is( $line->[1], $msg, "  |_  Message string is expected." );
    }

    return;
}
