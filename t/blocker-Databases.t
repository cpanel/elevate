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

my $cpev_mock = Test::MockModule->new('cpev');

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
    note 'cPanel MySQL behavior';

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';

        local $Cpanel::Version::Tiny::major_version = 110;
        is(
            $db->_blocker_old_cpanel_mysql('5.7'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_cpanel_mysql],
                msg => <<~"EOS",
    You are using MySQL 5.7 server.
    This version is not available for $expected_target_os.
    You first need to update your MySQL server to 8.0 or later.

    You can update to version 8.0 using the following command:

        /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=8.0

    Once the MySQL upgrade is finished, you can then retry to elevate to $expected_target_os.
    EOS
            },
            'MySQL 5.7 is a blocker.'
        );

        is(
            $db->_blocker_old_cpanel_mysql('10.1'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_cpanel_mysql],
                msg => <<~"EOS",
        You are using MariaDB server 10.1, this version is not available for $expected_target_os.
        You first need to update MariaDB server to 10.5 or later.

        You can update to version 10.5 using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.5

        Once the MariaDB upgrade is finished, you can then retry to elevate to $expected_target_os.
        EOS
            },
            'Maria 10.1 is a blocker.'
        );

        is(
            $db->_blocker_old_cpanel_mysql('10.2'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_cpanel_mysql],
                msg => <<~"EOS",
        You are using MariaDB server 10.2, this version is not available for $expected_target_os.
        You first need to update MariaDB server to 10.5 or later.

        You can update to version 10.5 using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.5

        Once the MariaDB upgrade is finished, you can then retry to elevate to $expected_target_os.
        EOS
            },
            'Maria 10.2 is a blocker.'
        );

        is(
            $db->_blocker_old_cpanel_mysql('4.2'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_cpanel_mysql],
                msg => <<~"EOS",
        We do not know how to upgrade to $expected_target_os with MySQL version 4.2.
        Please upgrade your MySQL server to one of the supported versions before running elevate.

        Supported MySQL server versions are: 8.0, 10.3, 10.4, 10.5, 10.6
        EOS
            },
            'MySQL 4.2 is a blocker.'
        );
    }

    my $stash = undef;
    $cpev_mock->redefine(
        update_stage_file => sub { $stash = $_[0] },
    );

    is( $db->_blocker_old_cpanel_mysql('8.0'), 0, "MySQL 8 and we're ok" );
    is $stash, { 'mysql-version' => '8.0' }, " - Stash is updated";
    is( $db->_blocker_old_cpanel_mysql('10.3'), 0, "Maria 10.3 and we're ok" );
    is $stash, { 'mysql-version' => '10.3' }, " - Stash is updated";
    is( $db->_blocker_old_cpanel_mysql('10.4'), 0, "Maria 10.4 and we're ok" );
    is $stash, { 'mysql-version' => '10.4' }, " - Stash is updated";
    is( $db->_blocker_old_cpanel_mysql('10.5'), 0, "Maria 10.5 and we're ok" );
    is $stash, { 'mysql-version' => '10.5' }, " - Stash is updated";
    is( $db->_blocker_old_cpanel_mysql('10.6'), 0, "Maria 10.6 and we're ok" );
    is $stash, { 'mysql-version' => '10.6' }, " - Stash is updated";
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
    $cpev_mock->redefine(
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

    $cpev_mock->unmock('read_stage_file');
}

{
    note 'Test _blocker_old_mysql()';

    $cpev_mock->redefine(
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

    $cpev_mock->unmock('read_stage_file');
}

done_testing();
