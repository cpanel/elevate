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

use File::Slurper qw{read_text};
use JSON::XS      ();

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Cpanel::DB::Map::Collection::Index ();

use cPstrict;

my $db = cpev->new->get_component('MySQL');

my $mock_elevate       = Test::MockFile->file('/var/cpanel/elevate');
my $mock_version_cache = Test::MockFile->file('/var/cpanel/mysql_server_version_cache');

{
    note "mysql upgrade in progress";
    my $mf_mysql_upgrade = Test::MockFile->file( q[/var/cpanel/mysql_upgrade_in_progress] => 1 );
    is(
        $db->_blocker_mysql_upgrade_in_progress(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_mysql_upgrade_in_progress],
            msg => "MySQL/MariaDB upgrade in progress. Please wait for the upgrade to finish.",
        },
        q{Block if mysql is upgrading.}
    );

    $mf_mysql_upgrade->unlink;
    is( $db->_blocker_mysql_upgrade_in_progress(), 0, q[MySQL upgrade is not in progress.] );
}

{
    note 'cPanel MySQL behavior';

    set_os_to('cent');

    clear_messages_seen();

    my $test_db_version = '13';
    my $is_db_supported = 1;
    my $upgrade_version = '42';
    my $stash           = undef;
    my $is_check_mode   = 1;
    my $os_pretty_name  = 'AlmaLinux 8';
    my $user_consent    = 0;

    my $mock_db = Test::MockModule->new('Elevate::Database');
    $mock_db->redefine(
        get_local_database_version          => sub { return $test_db_version; },
        is_database_version_supported       => sub { return $is_db_supported; },
        get_default_upgrade_version         => sub { return $upgrade_version; },
        get_database_type_name_from_version => sub { return ( $_[0] eq $test_db_version ) ? 'OldDB' : 'NewDB' },
    );

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        update_stage_file => sub { $stash = $_[0] },
    );

    my $mock_db_blocker = Test::MockModule->new('Elevate::Components::MySQL');
    $mock_db_blocker->redefine(
        is_check_mode => sub { return $is_check_mode; },
    );

    my $mock_io_prompt = Test::MockModule->new('IO::Prompt');
    $mock_io_prompt->redefine(
        prompt => sub { return $user_consent; },
    );

    # Test supported DB server (one that doesn't need an upgrade)
    is( $db->_blocker_old_cpanel_mysql(), 0, "Supported database returns 0" );
    no_messages_seen();
    is( $stash, { 'mysql-version' => $test_db_version }, 'Stage file updated with original version' );

    # The rest of the scenarios test where the DB server is NOT supported
    $is_db_supported = 0;
    $stash           = undef;

    # Test warning for check mode
    $is_check_mode = 1;
    is( $db->_blocker_old_cpanel_mysql(), 0,     "Check mode returns 0" );
    is( $stash,                           undef, 'Stage file not updated due to running a check' );
    message_seen(
        'WARN',
        qr/You have OldDB $test_db_version installed.\nThis version is not available for $os_pretty_name/
    );
    message_seen( 'INFO', qr/whmapi1 start_background_mysql_upgrade version=$upgrade_version/ );

    # Test for start mode, but the user declines
    $is_check_mode = 0;
    $user_consent  = 0;
    like(
        $db->_blocker_old_cpanel_mysql(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_old_cpanel_mysql],
            msg => qr/The system cannot be elevated to $os_pretty_name until OldDB has been upgraded./
        },
        'Returns blocker if user declines the upgrade'
    );
    is( $stash, undef, 'Stage file not updated due to blocker' );
    message_seen(
        'WARN',
        qr/You have OldDB $test_db_version installed.\nThis version is not available for $os_pretty_name/
    );
    message_seen(
        'WARN',
        qr/automatically upgrade .*to NewDB $upgrade_version/s
    );
    message_seen(
        'WARN',
        qr/The system cannot be elevated to $os_pretty_name until OldDB has been upgraded./
    );

    # Test for start mode where the user accepts
    $user_consent = 1;
    is(
        $db->_blocker_old_cpanel_mysql(),
        0,
        "Returns 0 when user agrees to upgrade"
    );
    is( $stash, { 'mysql-version' => $upgrade_version }, 'Stage file updated with upgrade version' );
    message_seen(
        'WARN',
        qr/You have OldDB $test_db_version installed.\nThis version is not available for $os_pretty_name/
    );
    message_seen(
        'WARN',
        qr/automatically upgrade .*to NewDB $upgrade_version/s
    );
}

{
    note 'Test CloudLinux MySQL blocker';
    set_os_to('cloud');

    my $db_version = 106;

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        read_stage_file => sub {
            return {
                db_type    => 'foo',
                db_version => $db_version,
            };
        },
    );

    is( $db->_blocker_old_cloudlinux_mysql(), 0, '10.6 is supported by CL' );

    $db_version = 51;
    is(
        $db->_blocker_old_cloudlinux_mysql(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_old_cloudlinux_mysql],
            msg => <<~'EOS',
You are using foo 5.1 server.
This version is not available for CloudLinux 8.
You first need to update your database server software to version 5.5 or later.

Please review the following documentation for instructions
on how to update to a newer version with MySQL Governor:

    https://docs.cloudlinux.com/shared/cloudlinux_os_components/#upgrading-database-server

Once the upgrade is finished, you can then retry to ELevate to CloudLinux 8.
EOS
        },
        '5.1 is a blocker for CL',
    );
}

{
    note 'Test _blocker_old_mysql()';

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        read_stage_file => sub {
            return {
                db_type    => 'foo',
                db_version => 55,
            };
        },
    );

    my $mock_cpanel_config_loadcpconf = Test::MockModule->new('Cpanel::Config::LoadCpConf');
    $mock_cpanel_config_loadcpconf->redefine(
        loadcpconf => sub {
            return {
                'mysql-version' => '8.0',
            };
        },
    );

    local *Elevate::Database::is_database_provided_by_cloudlinux = sub { return 1; };
    is( $db->_blocker_old_mysql(), 0, '5.5 is supported by CL' );

    local *Elevate::Database::is_database_provided_by_cloudlinux = sub { return 0; };
    is( $db->_blocker_old_mysql(), 0, '8.0 is supported by cPanel' );
}

{
    note 'Test _blocker_mysql_database_corrupted';

    clear_messages_seen();

    my $is_mysql_local;
    my $is_mysql_running;
    my $is_mysql_enabled;
    my $restart_mysql;
    my @ssystem_output;

    my $mock_dbutils = Test::MockModule->new('Cpanel::DbUtils');
    $mock_dbutils->redefine(
        find_mysqlcheck => sub { return '/usr/bin/mysqlcheck'; },
    );

    my $mock_mysqlutils_mycnf = Test::MockModule->new('Cpanel::MysqlUtils::MyCnf::Basic');
    $mock_mysqlutils_mycnf->redefine(
        is_local_mysql => sub { return $is_mysql_local; },
    );

    my $mock_mysqlutils_running = Test::MockModule->new('Cpanel::MysqlUtils::Running');
    $mock_mysqlutils_running->redefine(
        is_mysql_running => sub { return $is_mysql_running; },
    );

    my $mock_services = Test::MockModule->new('Cpanel::Services::Enabled');
    $mock_services->redefine(
        is_enabled => sub { return $is_mysql_enabled; },
    );

    my $mock_comp = Test::MockModule->new('Elevate::Components::MySQL');
    $mock_comp->redefine(
        'ssystem_capture_output' => sub {
            $is_mysql_running = 1 if ($restart_mysql);
            return { status => 0, stdout => \@ssystem_output, stderr => [] };
        },
    );

    $is_mysql_local   = 0;
    $is_mysql_running = 1;
    $is_mysql_enabled = 1;
    $restart_mysql    = 0;
    @ssystem_output   = ();

    is( $db->_blocker_mysql_database_corrupted(), 0, 'Do not block if MySQL not local' );
    no_messages_seen();

    $is_mysql_local   = 1;
    $is_mysql_running = 0;
    $is_mysql_enabled = 0;

    is( $db->_blocker_mysql_database_corrupted(), 0, 'Do not block if MySQL not running and not enabled' );
    no_messages_seen();    # Don't complain if not running because not enabled;

    $is_mysql_running = 0;
    $is_mysql_enabled = 1;
    $restart_mysql    = 0;
    @ssystem_output   = ();

    my $mock_elevate_comp = Test::MockModule->new('Elevate::Components');
    $mock_elevate_comp->redefine(
        is_check_mode => 1,
    );

    is( $db->_blocker_mysql_database_corrupted(), 0, 'The check is a noop in check mode' );

    $mock_elevate_comp->redefine(
        is_check_mode => 0,
    );

    like(
        $db->_blocker_mysql_database_corrupted(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_mysql_database_corrupted],
            msg => qr/Unable to to start the database server/
        },
        'Blocks if we cannot restart the database server'
    );

    $restart_mysql = 1;

    like(
        $db->_blocker_mysql_database_corrupted(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_mysql_database_corrupted],
            msg => qr/Unable to to start the database server/
        },
        'Blocks if we cannot restart the database server'
    );

    $is_mysql_running = 0;
    $restart_mysql    = 0;
    @ssystem_output   = ('mysql started successfully.');

    like(
        $db->_blocker_mysql_database_corrupted(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_mysql_database_corrupted],
            msg => qr/Unable to to start the database server/
        },
        'Blocks if we cannot restart the database server'
    );

    $restart_mysql = 1;

    clear_messages_seen();
    is( $db->_blocker_mysql_database_corrupted(), 0, 'Do not block if we could restart MySQL and no DB errors' );
    message_seen(
        'WARN',
        'Database server was down, starting it to check database integrity'
    );
    no_messages_seen();

    $is_mysql_running = 1;
    $is_mysql_enabled = 1;
    @ssystem_output   = (
        'Warning  : InnoDB: Tablespace is missing for table classicmodels/offices.',
    );

    is( $db->_blocker_mysql_database_corrupted(), 0, 'Do not block if mysqlcheck gives only warnings' );
    no_messages_seen();

    $is_mysql_running = 1;
    $is_mysql_enabled = 1;
    @ssystem_output   = (
        'Warning  : InnoDB: Tablespace is missing for table classicmodels/offices.',
        'Error    : Tablespace is missing for table `classicmodels`.`offices`.',
    );

    like(
        $db->_blocker_mysql_database_corrupted(),
        {
            id  => q[Elevate::Components::MySQL::_blocker_mysql_database_corrupted],
            msg => qr/We have found the following problems with your database/
        },
        'Blocks if mysqlcheck reports errors'
    );
}

done_testing();
