#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

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

my $cpev = cpev->new;
my $db   = $cpev->get_blocker('Databases');

my $mock_elevate = Test::MockFile->file('/var/cpanel/elevate');

{
    note "mysql upgrade in progress";
    my $mf_mysql_upgrade = Test::MockFile->file( q[/var/cpanel/mysql_upgrade_in_progress] => 1 );
    is(
        $db->_blocker_mysql_upgrade_in_progress(),
        {
            id  => q[Elevate::Blockers::Databases::_blocker_mysql_upgrade_in_progress],
            msg => "MySQL upgrade in progress. Please wait for the MySQL upgrade to finish.",
        },
        q{Block if mysql is upgrading.}
    );

    $mf_mysql_upgrade->unlink;
    is( $db->_blocker_mysql_upgrade_in_progress(), 0, q[MySQL upgrade is not in progress.] );
}

{
    note 'Remote MySQL blocker';

    clear_messages_seen();

    my $is_remote_mysql = 0;

    my $mock_basic = Test::MockModule->new('Cpanel::MysqlUtils::MyCnf::Basic');
    $mock_basic->redefine(
        is_remote_mysql => sub { return $is_remote_mysql; },
    );

    is( $db->_blocker_remote_mysql(), 0, 'No blocker if remote MySQL disabled' );
    no_messages_seen();

    # Test blocker on remote mysql
    $is_remote_mysql = 1;
    like(
        $db->_blocker_remote_mysql(),
        {
            id  => q[Elevate::Blockers::Databases::_blocker_remote_mysql],
            msg => qr/The system is currently setup to use a remote database server/,
        },
        'Returns blocker if remote MySQL is enabled'
    );
    message_seen( 'WARN', qr/remote database server/ );
}

{
    note 'cPanel MySQL behavior';

    clear_messages_seen();

    my $test_db_version = '13';
    my $is_db_supported = 1;
    my $upgrade_version = '42';
    my $stash           = undef;
    my $is_check_mode   = 1;
    my $os_pretty_name  = 'ShinyOS';
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

    my $mock_db_blocker = Test::MockModule->new('Elevate::Blockers::Databases');
    $mock_db_blocker->redefine(
        is_check_mode          => sub { return $is_check_mode; },
        upgrade_to_pretty_name => sub { return $os_pretty_name; },
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
            id  => q[Elevate::Blockers::Databases::_blocker_old_cpanel_mysql],
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
    note "Postgresql 9.6/CCS";

    clear_messages_seen();

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';

        my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
        my %installed = ( 'cpanel-ccs-calendarserver' => 9.2, 'postgresql-server' => 9.2 );
        $pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
        $pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

        is( $db->_warning_if_postgresql_installed, 2, "pg 9 is installed" );
        message_seen( 'WARN', "You have postgresql-server version 9.2 installed. This will be upgraded irreversibly to version 10.0 when you switch to $expected_target_os" );

        $installed{'postgresql-server'} = '10.2';
        is( $db->_warning_if_postgresql_installed, 1, "pg 10 is installed so no warning" );
        no_messages_seen();

        $installed{'postgresql-server'} = 'an_unexpected_version';
        is( $db->_warning_if_postgresql_installed, 1, "unknown pg version is installed so no warning" );
        no_messages_seen();

        delete $installed{'postgresql-server'};
        is( $db->_warning_if_postgresql_installed, 0, "pg is not installed so no warning" );
        no_messages_seen();
    }

}

{
    note "PostgreSQL 9.2->10 acknowledgement";

    my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
    my %installed = ( 'postgresql-server' => 9.2 );
    $pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
    $pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

    my $mock_touchfile = Test::MockFile->file('/var/cpanel/acknowledge_postgresql_for_elevate');

    my $db_mock = Test::MockModule->new('Elevate::Blockers::Databases');

    my @mock_users = qw(cpuser1 cpuser2);
    $db_mock->redefine( _has_mapped_postgresql_dbs => sub { return @mock_users } );

    my $expected = {
        id  => q[Elevate::Blockers::Databases::_blocker_acknowledge_postgresql_datadir],
        msg => <<~'EOS'
        One or more users on your system have associated PostgreSQL databases.
        ELevate may upgrade the software packages associated with PostgreSQL
        automatically, but if it does, it will *NOT* automatically update the
        PostgreSQL data directory to work with the new version. Without an update
        to the data directory, the upgraded PostgreSQL software will not start, in
        order to ensure that your data does not become corrupted.

        For more information about PostgreSQL upgrades, please consider the
        following resources:

        https://cpanel.github.io/elevate/blockers/#postgresql
        https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/using-databases#migrating-to-a-rhel-8-version-of-postgresql_using-postgresql
        https://www.postgresql.org/docs/10/pgupgrade.html

        When you are ready to acknowledge that you have prepared to update the
        PostgreSQL data directory, or that this warning does not apply to you,
        please touch the following file to continue with the ELevate process:

        > touch /var/cpanel/acknowledge_postgresql_for_elevate

        The following user(s) have PostgreSQL databases associated with their cPanel accounts:
        cpuser1
        cpuser2
        EOS
    };
    chomp $expected->{msg};
    is(
        $db->_blocker_acknowledge_postgresql_datadir(),
        $expected,
        "PostgreSQL with cPanel users having databases and without ACK touch file is a blocker"
    );

    %installed = ();
    is( $db->_blocker_acknowledge_postgresql_datadir(), 0, "No blocker if no postgresql-server package" );
    %installed = ( 'postgresql-server' => 9.2 );

    $mock_touchfile->touch();
    is( $db->_blocker_acknowledge_postgresql_datadir(), 0, "No blocker if touch file present" );
    $mock_touchfile->unlink();

    @mock_users = ();
    is( $db->_blocker_acknowledge_postgresql_datadir(), 0, "No blocker if no users have PgSQL DBs" );
    @mock_users = qw(cpuser1 cpuser2);
}

{
    note "check for PostgreSQL databases";

    # This keeps Cpanel::Exception::get_string() from causing errors
    # when trying to access locale files
    local $Cpanel::Exception::LOCALIZE_STRINGS = 0;

    # Cpanel::Transaction::File::JSONReader will do some low-level file
    # calls that get around Test::MockFile.  This is needed to ensure that the
    # contents of the mocked dbindex file are read rather than the real one.
    my $mock_reader = Test::MockModule->new("Cpanel::Transaction::File::JSONReader");
    $mock_reader->redefine(
        new => sub ( $class, %opts ) {
            my $self = {};
            bless $self, 'Cpanel::Transaction::File::JSONReader';
            $self->{path} = $opts{path};
            return $self;
        },
        get_data => sub ($self) {
            my $contents = read_text( $self->{path} );
            return undef if !defined $contents;

            my $json_obj = JSON::XS->new->ascii->pretty->allow_nonref;
            my $hr       = $json_obj->decode($contents);
            return $hr;
        }
    );

    my $mock_dbindex_file = Test::MockFile->file( Cpanel::DB::Map::Collection::Index::_cache_file_path() );

    # There should be an error for a bogus dbindex file.
    $mock_dbindex_file->contents('this is not json');
    clear_messages_seen();
    is( [ $db->_has_mapped_postgresql_dbs() ], [], 'Bogus index file returns no users' );
    message_seen( 'ERROR', qr{Unable to read the database index file.*this is not json} );
    message_seen( 'WARN',  qr{Elevation Blocker detected.*rebuild it by running:\s+/usr/local/cpanel/bin/dbindex}s );

    $mock_dbindex_file->contents( <<~EOS );
    {
        "PGSQL": {
            "pgdb_01": "pgdb_user_01",
            "pgdb_02": "pgdb_user_01",
            "pgdb_03": "pgdb_user_01",
            "pgdb_04": "pgdb_user_02",
            "pgdb_05": "pgdb_user_02",
            "pgdb_06": "pgdb_user_02",
            "pgdb_07": "pgdb_user_03",
            "pgdb_08": "pgdb_user_03",
            "pgdb_09": "pgdb_user_03",
            "pgdb_10": "pgdb_user_04"
        },
        "MYSQL": {
            "mysqldb_01": "cpuser_01",
            "mysqldb_02": "cpuser_01",
            "mysqldb_03": "cpuser_02",
            "mysqldb_04": "cpuser_02",
            "mysqldb_05": "cpuser_02"
        }
    }
    EOS

    is(
        [ $db->_has_mapped_postgresql_dbs() ],
        bag {
            item 'pgdb_user_01';
            item 'pgdb_user_02';
            item 'pgdb_user_03';
            item 'pgdb_user_04';
            end();
        },
        "_has_mapped_postgresql_dbs returns expected list of users"
    );

    no_messages_seen();
}

{
    note 'Test CloudLinux MySQL blocker';
    set_os_to('cloud');

    local *Elevate::OS::upgrade_to = sub { return 'CloudLinux'; };

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
            id  => q[Elevate::Blockers::Databases::_blocker_old_cloudlinux_mysql],
            msg => <<~'EOS',
You are using MySQL 5.1 server.
This version is not available for CloudLinux 8.
You first need to update your MySQL server to 5.5 or later.

Please review the following documentation for instructions
on how to update to a newer MySQL Version with MySQL Governor:

    https://docs.cloudlinux.com/shared/cloudlinux_os_components/#upgrading-database-server

Once the MySQL upgrade is finished, you can then retry to elevate to CloudLinux 8.
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

done_testing();
