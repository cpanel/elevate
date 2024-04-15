package Elevate::Blockers::Databases;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Databases

Blockers for datbase: MySQL, PostgreSQL...

=cut

use cPstrict;

use Elevate::Database  ();
use Elevate::StageFile ();

use Cpanel::OS                         ();
use Cpanel::Pkgr                       ();
use Cpanel::Version::Tiny              ();
use Cpanel::JSON                       ();
use Cpanel::SafeRun::Simple            ();
use Cpanel::DB::Map::Collection::Index ();
use Cpanel::Exception                  ();
use Cpanel::MysqlUtils::MyCnf::Basic   ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

use constant POSTGRESQL_ACK_TOUCH_FILE => q[/var/cpanel/acknowledge_postgresql_for_elevate];

sub check ($self) {
    my $ok = 1;
    $self->_warning_if_postgresql_installed;
    $ok = 0 unless $self->_blocker_acknowledge_postgresql_datadir;
    $ok = 0 unless $self->_blocker_remote_mysql;
    $ok = 0 unless $self->_blocker_old_mysql;
    $ok = 0 unless $self->_blocker_mysql_upgrade_in_progress;
    $self->_warning_mysql_not_enabled();
    return $ok;
}

sub _warning_if_postgresql_installed ($self) {
    return 0 unless Cpanel::Pkgr::is_installed('postgresql-server');

    my $pg_full_ver = Cpanel::Pkgr::get_package_version('postgresql-server');
    my ($old_version) = $pg_full_ver =~ m/^(\d+\.\d+)/a;
    return 1 if !$old_version || $old_version >= 10;

    my $pretty_distro_name = $self->upgrade_to_pretty_name();
    WARN("You have postgresql-server version $old_version installed. This will be upgraded irreversibly to version 10.0 when you switch to $pretty_distro_name");

    return 2;
}

sub _blocker_acknowledge_postgresql_datadir ($self) {

    return 0 unless Cpanel::Pkgr::is_installed('postgresql-server');

    my $touch_file = POSTGRESQL_ACK_TOUCH_FILE;
    return 0 if -e $touch_file;

    my @users_with_dbs = $self->_has_mapped_postgresql_dbs();
    return 0 unless scalar @users_with_dbs;

    my $message = <<~"EOS";
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

    > touch $touch_file

    The following user(s) have PostgreSQL databases associated with their cPanel accounts:
    EOS

    $message .= join "\n", sort(@users_with_dbs);

    return $self->has_blocker($message);
}

sub _has_mapped_postgresql_dbs ($self) {

    my $dbindex = eval { Cpanel::DB::Map::Collection::Index->new( { db => 'PGSQL' } ); };
    if ( my $exception = $@ ) {
        ERROR( 'Unable to read the database index file:  ' . Cpanel::Exception::get_string($exception) );
        $self->has_blocker("Unable to read the database index file; you may need to rebuild it by running: /usr/local/cpanel/bin/dbindex");
        return ();
    }

    my %user_hash = map { $dbindex->{dbindex}{$_} => 1 } keys %{ $dbindex->{dbindex} };

    return ( keys %user_hash );
}

sub _blocker_remote_mysql ($self) {

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    # If we are setup to use remote MySQL, then attempting an upgrade will fail
    # TODO: Temporarily disable remote MySQL to allow the database upgrade
    if ( Cpanel::MysqlUtils::MyCnf::Basic::is_remote_mysql() ) {
        return $self->has_blocker( <<~"EOS" );
        The system is currently setup to use a remote database server.
        We cannot elevate the system to $pretty_distro_name
        unless the system is configured to use the local database server.
        EOS
    }

    return 0;
}

sub _blocker_old_mysql ($self) {

    my $mysql_is_provided_by_cloudlinux = Elevate::Database::is_database_provided_by_cloudlinux(0);

    return $mysql_is_provided_by_cloudlinux ? $self->_blocker_old_cloudlinux_mysql() : $self->_blocker_old_cpanel_mysql();
}

sub _blocker_old_cloudlinux_mysql ($self) {
    my ( $db_type, $db_version ) = Elevate::Database::get_db_info_if_provided_by_cloudlinux();

    # 5.5 gets stored as 55 and so on and so forth since there are no .'s
    # for the version in the RPM package name
    return 0 if length $db_version && $db_version >= 55;

    my $pretty_distro_name = $self->upgrade_to_pretty_name();
    my $db_dot_version     = $db_version;

    # Shift decimal one place to the left
    # 80 becomes 8.0
    # 102 becomes 10.2
    $db_dot_version =~ s/([0-9])$/\.$1/;

    return $self->has_blocker( <<~"EOS");
    You are using MySQL $db_dot_version server.
    This version is not available for $pretty_distro_name.
    You first need to update your MySQL server to 5.5 or later.

    Please review the following documentation for instructions
    on how to update to a newer MySQL Version with MySQL Governor:

        https://docs.cloudlinux.com/shared/cloudlinux_os_components/#upgrading-database-server

    Once the MySQL upgrade is finished, you can then retry to elevate to $pretty_distro_name.
    EOS
}

sub _blocker_old_cpanel_mysql ($self) {

    my $mysql_version = Elevate::Database::get_local_database_version();

    # If we are running a local version of MySQL/MariaDB that will be
    # supported by the new OS version, we leave it as it is.
    if ( Elevate::Database::is_database_version_supported($mysql_version) ) {

        # store the MySQL version we started from
        Elevate::StageFile::update_stage_file( { 'mysql-version' => $mysql_version } );
        return 0;
    }

    my $pretty_distro_name  = $self->upgrade_to_pretty_name();
    my $database_type_name  = Elevate::Database::get_database_type_name_from_version($mysql_version);
    my $upgrade_version     = Elevate::Database::get_default_upgrade_version();
    my $upgrade_dbtype_name = Elevate::Database::get_database_type_name_from_version($upgrade_version);

    WARN( <<~"EOS" );
    You have $database_type_name $mysql_version installed.
    This version is not available for $pretty_distro_name.

    EOS

    if ( $self->is_check_mode() ) {
        INFO( <<~"EOS" );
        You can manually upgrade your installation of $database_type_name using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=$upgrade_version

        Once the MySQL upgrade is finished, you can then retry to elevate to $pretty_distro_name.

        EOS
        return 0;
    }

    WARN( <<~"EOS" );
    Prior to elevating this system to $pretty_distro_name,
    we will automatically upgrade your installation of $database_type_name
    to $upgrade_dbtype_name $upgrade_version.

    EOS

    if ( !$self->getopt('non-interactive') ) {
        if (
            !IO::Prompt::prompt(
                '-one_char',
                '-yes_no',
                '-tty',
                -default => 'y',
                "Do you consent to upgrading to $upgrade_dbtype_name $upgrade_version [Y/n]: ",
            )
        ) {
            return $self->has_blocker( <<~"EOS" );
            The system cannot be elevated to $pretty_distro_name until $database_type_name has been upgraded. To upgrade manually:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=$upgrade_version

            To have have this script perform the upgrade, run this script again and consent to allow it to upgrade $upgrade_dbtype_name $upgrade_version.

            EOS
        }
    }

    # Change to the version we will uprade to
    Elevate::StageFile::update_stage_file( { 'mysql-version' => $upgrade_version } );

    return 0;
}

sub _blocker_mysql_upgrade_in_progress ($self) {
    if ( -e q[/var/cpanel/mysql_upgrade_in_progress] ) {
        return $self->has_blocker(q[MySQL upgrade in progress. Please wait for the MySQL upgrade to finish.]);
    }

    return 0;
}

sub _warning_mysql_not_enabled ($self) {
    require Cpanel::Services::Enabled;
    my $enabled = Cpanel::Services::Enabled::is_enabled('mysql');

    Elevate::StageFile::update_stage_file( { 'mysql-enabled' => $enabled } );
    WARN( "MySQL is disabled. This must be enabled for MySQL upgrade to succeed.\n" . "We temporarily will enable it when it is needed to be enabled,\n" . "but we reccomend starting the process with MySQL enabled." ) if !$enabled;
    return 0;
}

1;
