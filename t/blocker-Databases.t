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

my $cpev_mock = Test::MockModule->new('cpev');
my $db_mock   = Test::MockModule->new('Elevate::Blockers::Databases');

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
    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';

        is(
            $db->_blocker_old_mysql('5.7'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_mysql],
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

        local $Cpanel::Version::Tiny::major_version = 108;
        is(
            $db->_blocker_old_mysql('10.1'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_mysql],
                msg => <<~"EOS",
        You are using MariaDB server 10.1, this version is not available for $expected_target_os.
        You first need to update MariaDB server to 10.3 or later.

        You can update to version 10.3 using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.3

        Once the MariaDB upgrade is finished, you can then retry to elevate to $expected_target_os.
        EOS
            },
            'Maria 10.1 on 108 is a blocker.'
        );

        $Cpanel::Version::Tiny::major_version = 110;
        is(
            $db->_blocker_old_mysql('10.2'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_mysql],
                msg => <<~"EOS",
        You are using MariaDB server 10.2, this version is not available for $expected_target_os.
        You first need to update MariaDB server to 10.5 or later.

        You can update to version 10.5 using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.5

        Once the MariaDB upgrade is finished, you can then retry to elevate to $expected_target_os.
        EOS
            },
            'Maria 10.2 on 110 is a blocker.'
        );

        is(
            $db->_blocker_old_mysql('4.2'),
            {
                id  => q[Elevate::Blockers::Databases::_blocker_old_mysql],
                msg => <<~"EOS",
        We do not know how to upgrade to $expected_target_os with MySQL version 4.2.
        Please upgrade your MySQL server to one of the supported versions before running elevate.

        Supported MySQL server versions are: 8.0, 10.3, 10.4, 10.5, 10.6
        EOS
            },
            'Maria 10.2 on 110 is a blocker.'
        );
    }

    my $stash = undef;
    $cpev_mock->redefine(
        update_stage_file => sub { $stash = $_[0] },
    );

    is( $db->_blocker_old_mysql('8.0'), 0, "MySQL 8 and we're ok" );
    is $stash, { 'mysql-version' => '8.0' }, " - Stash is updated";
    is( $db->_blocker_old_mysql('10.3'), 0, "Maria 10.3 and we're ok" );
    is $stash, { 'mysql-version' => '10.3' }, " - Stash is updated";
    is( $db->_blocker_old_mysql('10.4'), 0, "Maria 10.4 and we're ok" );
    is $stash, { 'mysql-version' => '10.4' }, " - Stash is updated";
    is( $db->_blocker_old_mysql('10.5'), 0, "Maria 10.5 and we're ok" );
    is $stash, { 'mysql-version' => '10.5' }, " - Stash is updated";
    is( $db->_blocker_old_mysql('10.6'), 0, "Maria 10.6 and we're ok" );
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

    my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');

    $mock_saferun->redefine(
        saferunnoerror => sub {
            return $_[0] eq '/usr/local/cpanel/bin/whmapi1'
              ? '{"metadata":{"command":"list_users","version":1,"reason":"OK","result":1},"data":{"users":["root","cpuser2","cpuser1"]}}'
              : '{"apiversion":3,"module":"Postgresql","func":"list_databases","result":{"warnings":null,"data":[{"disk_usage":9001,"database":"dontcare","users":["dontcare"]}],"errors":null,"metadata":{"transformed":1},"status":1,"messages":null}}';
        }
    );

    is(
        [ $db->_has_mapped_postgresql_dbs() ],
        bag {
            item 'cpuser1';
            item 'cpuser2';
            end();
        },
        "_has_mapped_postgresql_dbs returns expected list of users"
    );
}

done_testing();
