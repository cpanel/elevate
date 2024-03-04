package Elevate::Blockers::Databases;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Databases

Blockers for datbase: MySQL, PostgreSQL...

=cut

use cPstrict;

use Elevate::Database ();

use Cpanel::OS                         ();
use Cpanel::Pkgr                       ();
use Cpanel::Version::Tiny              ();
use Cpanel::JSON                       ();
use Cpanel::SafeRun::Simple            ();
use Cpanel::DB::Map::Collection::Index ();
use Cpanel::Exception                  ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

use constant POSTGRESQL_ACK_TOUCH_FILE => q[/var/cpanel/acknowledge_postgresql_for_elevate];

sub check ($self) {
    my $ok = 1;
    $self->_warning_if_postgresql_installed;
    $ok = 0 unless $self->_blocker_acknowledge_postgresql_datadir;
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

sub _blocker_old_mysql ($self) {

    my $mysql_is_provided_by_cloudlinux = Elevate::Database::is_database_provided_by_cloudlinux(0);

    return $mysql_is_provided_by_cloudlinux ? $self->_blocker_old_cloudlinux_mysql() : $self->_blocker_old_cpanel_mysql();
}

# TODO: RE-234 implement this
sub _blocker_old_cloudlinux_mysql ($self) {
    return;
}

sub _blocker_old_cpanel_mysql ( $self, $mysql_version = undef ) {
    $mysql_version //= $self->cpconf->{'mysql-version'} // '';

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    # checking MySQL version
    if ( $mysql_version =~ qr{^\d+(\.\d)?$}a ) {
        if ( 5 <= $mysql_version && $mysql_version <= 5.7 ) {
            return $self->has_blocker( <<~"EOS");
            You are using MySQL $mysql_version server.
            This version is not available for $pretty_distro_name.
            You first need to update your MySQL server to 8.0 or later.

            You can update to version 8.0 using the following command:

                /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=8.0

            Once the MySQL upgrade is finished, you can then retry to elevate to $pretty_distro_name.
            EOS
        }
        elsif ( 10 <= $mysql_version && $mysql_version <= 10.2 ) {

            # cPanel 110 no longer supports upgrades from something else to 10.3. Suggest 10.5 in that case:
            my $upgrade_version = $Cpanel::Version::Tiny::major_version <= 108 ? '10.3' : '10.5';

            return $self->has_blocker( <<~"EOS");
            You are using MariaDB server $mysql_version, this version is not available for $pretty_distro_name.
            You first need to update MariaDB server to $upgrade_version or later.

            You can update to version $upgrade_version using the following command:

                /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=$upgrade_version

            Once the MariaDB upgrade is finished, you can then retry to elevate to $pretty_distro_name.
            EOS
        }
    }

    my %supported_mysql_versions = (
        map { $_ => 1 }
          qw{
          8.0
          10.3
          10.4
          10.5
          10.6
          }
    );

    if ( !$supported_mysql_versions{$mysql_version} ) {
        my $supported_version_str = join( ", ", sort { $a <=> $b } keys %supported_mysql_versions );
        return $self->has_blocker( <<~"EOS");
            We do not know how to upgrade to $pretty_distro_name with MySQL version $mysql_version.
            Please upgrade your MySQL server to one of the supported versions before running elevate.

            Supported MySQL server versions are: $supported_version_str
            EOS
    }

    # store the MySQL version we started from
    cpev::update_stage_file( { 'mysql-version' => $mysql_version } );

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

    cpev::update_stage_file( { 'mysql-enabled' => $enabled } );
    WARN( "MySQL is disabled. This must be enabled for MySQL upgrade to succeed.\n" . "We temporarily will enable it when it is needed to be enabled,\n" . "but we reccomend starting the process with MySQL enabled." ) if !$enabled;
    return 0;
}

1;
