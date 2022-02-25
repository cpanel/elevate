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

use lib $FindBin::Bin. "/lib";
use Test::Elevate;

use cPstrict;

require $FindBin::Bin . '/../elevate-cpanel';

my $cpev_mock = Test::MockModule->new('cpev');
$cpev_mock->redefine( _init_logger => sub { die "should not call init_logger" } );

$cpev_mock->redefine( _check_yum_repos => 0 );

my $cpev = bless {}, 'cpev';

{
    no warnings 'once';
    local $Cpanel::Version::Tiny::major_version;
    is( $cpev->blockers_check(), 1, "no major_version means we're not cPanel?" );
    message_seen( 'ERROR', 'Invalid cPanel & WHM major_version' );

    $Cpanel::Version::Tiny::major_version = 98;
    is( $cpev->blockers_check(), 2, "11.98 is unsupported for this script." );
    message_seen( 'ERROR', qr/This version 11\.\d+\.\d+\.\d+ does not support upgrades to AlmaLinux 8. Please upgrade to cPanel version 102 or better/a );
}

{
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    my $f   = Test::MockFile->symlink( 'linux|centos|6|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
    my $rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

    my $m_custom = Test::MockFile->file(q[/var/cpanel/caches/Cpanel-OS.custom]);

    is( $cpev->blockers_check(), 3, "C6 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|8|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $cpev->blockers_check(), 3, "C8 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|cloudlinux|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $cpev->blockers_check(), 3, "CL7 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|4|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $cpev->blockers_check(), 4, "Need at least CentOS 7.9." );
    message_seen( 'ERROR', 'You need to run CentOS 7.9 and later to upgrade AlmaLinux 8. You are currently using CentOS v7.4.2009' );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    $m_custom->contents('');
    is( $cpev->blockers_check(), 5, "Custom OS is not supported." );
    message_seen( 'ERROR', 'Experimental OS detected. This script only supports CentOS 7 upgrades' );
}

# Dev sandbox
my $custom = Test::MockFile->file('/var/cpanel/caches/Cpanel-OS.custom');
my $f      = Test::MockFile->file( '/var/cpanel/dev_sandbox' => '' );

my $elevate_file = Test::MockFile->file('/var/cpanel/elevate');

is( $cpev->blockers_check(), 6, "Dev sandbox is a blocker.." );
message_seen( 'ERROR', 'Cannot elevate a sandbox...' );

$f->unlink;
my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
my %installed = ( 'cpanel-ccs-calendarserver' => 9.2, 'postgresql-server' => 9.2 );
$pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
$pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

is( $cpev->blockers_check(), 7, "CCS Calendar Server is a no go." );
message_seen( 'ERROR', qr{\QYou have the cPanel Calendar Server installed. Upgrades with this server in place are not supported.\E} );

delete $installed{'cpanel-ccs-calendarserver'};
is( $cpev->blockers_check(), 8, "Postgresql 9.2 won't upgrade well." );
message_seen( 'ERROR', <<'EOS' );
You have postgresql-server version 9.2 installed.
This is upgraded irreversably to version 10.0 when you switch to almalinux 8
We recommend data backup and removal of all postgresql packages before upgrade to AlmaLinux 8.
To re-install postgresql 9 on AlmaLinux 8, you can run: `dnf -y module enable postgresql:9.6; dnf -y install postgresql-server`
EOS

$installed{'postgresql-server'} = '10.0';
is( $cpev->blockers_check(), 8, "Postgresql 10 still is blocked." );
message_seen( 'ERROR', <<'EOS' );
You have postgresql-server version 10.0 installed.
We recommend data backup and removal of all postgresql packages before upgrade to AlmaLinux 8.
EOS
%installed = ();

my $cpconf_mock = Test::MockModule->new('Cpanel::Config::LoadCpConf');
my %cpanel_conf = ( 'local_nameserver_type' => 'nsd', 'mysql-version' => '5.7' );
$cpconf_mock->redefine( 'loadcpconf' => sub { return \%cpanel_conf } );

is( $cpev->blockers_check(), 9, "nsd blocks an upgrade to AlmaLinux 8" );
message_seen( 'ERROR', <<'EOS' );
AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns.
Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
EOS

$cpanel_conf{'local_nameserver_type'} = 'mydns';
is( $cpev->blockers_check(), 9, "mydns blocks an upgrade to AlmaLinux 8" );
message_seen( 'ERROR', <<'EOS' );
AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns.
Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
EOS

$cpanel_conf{'local_nameserver_type'} = 'powerdns';
is( $cpev->blockers_check(), 10, "the script location is incorrect." );
message_seen( 'ERROR', "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n" );

$0 = '/scripts/elevate-cpanel';
is( $cpev->blockers_check(), 11, "the script location is correct but MySQL 5.7 is installed." );
message_seen(
    'ERROR',
    "You are using MySQL 5.7 community server.\nThis version is not available for AlmaLinux 8.\nYou first need to update your MySQL server to 8.0 or later.\n\nYou can update to version 8.0 using the following command:\n\n    /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=8.0\n\nOnce the MySQL upgrade is finished, you can then retry to elevate to AlmaLinux 8.\n"
);

$cpanel_conf{'mysql-version'} = '10.2';
$0 = '/usr/local/cpanel/scripts/elevate-cpanel';
is( $cpev->blockers_check(), 12, "the script location is correct but MariaDB 10.2 is installed." );
message_seen(
    'ERROR',
    "You are using MariaDB server 10.2, this version is not available for AlmaLinux 8.\nYou first need to update MariaDB server to 10.3 or later.\n\nYou can update to version 10.3 using the following command:\n\n    /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.3\n\nOnce the MariaDB upgrade is finished, you can then retry to elevate to AlmaLinux 8.\n"
);

$cpanel_conf{'mysql-version'} = '4.0';
is( $cpev->blockers_check(), 13, 'An Unknown MySQL is present so we block for now.' );
message_seen( 'ERROR', "We do not know how to upgrade to AlmaLinux 8 with MySQL version 4.0.\nPlease open a support ticket.\n" );

$cpanel_conf{'mysql-version'} = '10.3';
$cpev_mock->redefine( _check_yum_repos => 1 );
is( $cpev->blockers_check(), 14, 'An Unknown MySQL is present so we block for now.' );
message_seen( 'ERROR', qr{YUM repo}i );
$cpev_mock->redefine( _check_yum_repos => 0 );

$cpanel_conf{'mysql-version'} = '8.0';
$cpev_mock->redefine( '_yum_is_stable' => 0 );
my $stage_file_updated;
$cpev_mock->redefine( 'save_stage_file' => sub { $stage_file_updated = shift } );
is( $cpev->blockers_check(), 15, 'blocked if yum is not stable.' );
message_seen( 'ERROR', qr{yum is not stable}i );

# Now we've tested the caller, let's test the code.
$cpev_mock->unmock('_yum_is_stable');
{
    note "Testing _yum_is_stable";
    my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');
    my $errors      = 'something is not right';
    $errors_mock->redefine( 'saferunonlyerrors' => sub { return $errors } );

    is( cpev::_yum_is_stable(), 0, "Yum is not stable and emits STDERR output (but does not exit non-zero)" );
    message_seen( 'ERROR', 'yum appears to be unstable. Please address this before upgrading' );
    message_seen( 'ERROR', 'something is not right' );
    $errors = '';

    #TODO Test::MockFile isn't working here.

    # my @stuff;
    # push @stuff, Test::MockFile->dir('/var/lib/yum');

    # is( cpev::_yum_is_stable(), 0, "/var/lib/yum is missing." );
    # message_seen( 'ERROR' => q{Could not read directory '/var/lib/yum': No such file or directory} );

    # mkdir '/var/lib/yum';
    # push @stuff, Test::MockFile->file( '/var/lib/yum/transaction-all.12345', 'aa' );
    # is( cpev::_yum_is_stable(), 0, "There is an outstanding transaction." );
    # message_seen( 'ERROR', 'There are unfinished yum transactions remaining. Please address these before upgrading. The tool `yum-complete-transaction` may help you with this task.' );

    # unlink '/var/lib/yum/transaction-all.12345';
    # is( cpev::_yum_is_stable(), 1, "No outstanding yum transactions are found. we're good to go!" );

}

$cpev_mock->redefine( '_disk_space_check' => 1 );
$cpev_mock->redefine( '_yum_is_stable'    => 1 );

$cpev_mock->redefine( '_sshd_setup' => 0 );
is( $cpev->blockers_check(), 16, 'blocked if sshd is not set properly' );

$cpev_mock->redefine( '_sshd_setup' => 1 );

$cpev_mock->redefine( '_use_jetbackup4_or_earlier' => 1 );
is( $cpev->blockers_check(), 17, 'blocked when using jetbackup 4 or earlier' );
$cpev_mock->redefine( '_use_jetbackup4_or_earlier' => 0 );

$cpev_mock->redefine( _system_update_check => 0 );
is( $cpev->blockers_check(), 101, 'System is up to date' );

$cpev_mock->redefine( _system_update_check => 1 );

is( $cpev->blockers_check(), 0, 'No More Blockers' );

{
    note "checking _sshd_setup";
    $cpev_mock->unmock('_sshd_setup');

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    is cpev::_sshd_setup() => 0, "sshd_config does not exist";

    $mock_sshd_cfg->contents('');
    is cpev::_sshd_setup() => 0, "sshd_config with empty content";

    $mock_sshd_cfg->contents( <<~EOS );
    Fruit=cherry
    Veggy=carrot
    EOS
    is cpev::_sshd_setup() => 0, "sshd_config without PermitRootLogin option";

    $mock_sshd_cfg->contents( <<~EOS );
    Key=value
    PermitRootLogin=yes
    EOS
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin=yes - multilines";

    $mock_sshd_cfg->contents(q[PermitRootLogin=no]);
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin no]);
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin  =  no]);
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin  =  no";

    $mock_sshd_cfg->contents(q[#PermitRootLogin=no]);
    is cpev::_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[#PermitRootLogin=yes]);
    is cpev::_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=yes";
}

{
    note "checking _use_jetbackup4_or_earlier";

    $cpev_mock->unmock('_use_jetbackup4_or_earlier');

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

}

{
    note "checking _system_update_check";
    my $status = 0;
    my @cmds;
    $cpev_mock->unmock('_system_update_check');
    $cpev_mock->redefine(
        ssystem => sub {
            push @cmds, [@_];
            return $status;
        }
    );

    ok cpev::_system_update_check(), '_system_update_check - success';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update}],
        ['/scripts/sysup']
      ],
      "check yum & sysup";

    @cmds   = ();
    $status = 1;

    is cpev::_system_update_check(), undef, '_system_update_check - failure';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update}],
      ],
      "check yum & abort";

}

done_testing();
exit;
