package Elevate::Blockers::Databases;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Databases

Blockers for datbase: MySQL, PostgreSQL...

=cut

use cPstrict;

use Cpanel::OS            ();
use Cpanel::Version::Tiny ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {
    $self->_warning_if_postgresql_installed;
    my $ok = $self->_blocker_old_mysql;
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

sub _blocker_old_mysql ( $self, $mysql_version = undef ) {

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
