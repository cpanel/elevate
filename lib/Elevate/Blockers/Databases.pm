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

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

my ( $db_type, $db_version );

sub check ($self) {
    my $ok = 1;
    $ok = 0 unless $self->_blocker_old_mysql;
    $ok = 0 unless $self->_blocker_mysql_upgrade_in_progress;
    $self->_warning_mysql_not_enabled();
    return $ok;
}

sub _blocker_old_mysql ($self) {

    my $mysql_is_provided_by_cloudlinux = Elevate::Database::is_database_provided_by_cloudlinux(0);

    return $mysql_is_provided_by_cloudlinux ? $self->_blocker_old_cloudlinux_mysql() : $self->_blocker_old_cpanel_mysql();
}

sub _blocker_old_cloudlinux_mysql ($self) {
    ( $db_type, $db_version ) = Elevate::Database::get_db_info_if_provided_by_cloudlinux();

    # 5.5 gets stored as 55 and so on and so forth since there are no .'s
    # for the version in the RPM package name
    return 0 if length $db_version && $db_version >= 55;

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
    $db_type = Elevate::Database::pretty_type_name($db_type);

    # Shift decimal one place to the left
    # 80 becomes 8.0
    # 102 becomes 10.2
    $db_version =~ s/([0-9])$/\.$1/;

    return $self->has_blocker( <<~"EOS");
    You are using $db_type $db_version server.
    This version is not available for $pretty_distro_name.
    You first need to update your database server software to version 5.5 or later.

    Please review the following documentation for instructions
    on how to update to a newer version with MySQL Governor:

        https://docs.cloudlinux.com/shared/cloudlinux_os_components/#upgrading-database-server

    Once the upgrade is finished, you can then retry to ELevate to $pretty_distro_name.
    EOS
}

sub _blocker_old_cpanel_mysql ($self) {

    $db_version = Elevate::Database::get_local_database_version();

    # If we are running a local version of MySQL/MariaDB that will be
    # supported by the new OS version, we leave it as it is.
    if ( Elevate::Database::is_database_version_supported($db_version) ) {

        # store the MySQL version we started from
        Elevate::StageFile::update_stage_file( { 'mysql-version' => $db_version } );
        return 0;
    }

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
    $db_type = Elevate::Database::get_database_type_name_from_version($db_version);
    my $upgrade_version     = Elevate::Database::get_default_upgrade_version();
    my $upgrade_dbtype_name = Elevate::Database::get_database_type_name_from_version($upgrade_version);

    WARN( <<~"EOS" );
    You have $db_type $db_version installed.
    This version is not available for $pretty_distro_name.

    EOS

    if ( $self->is_check_mode() ) {
        INFO( <<~"EOS" );
        You can manually upgrade your installation of $db_type using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=$upgrade_version

        Once the $db_type upgrade is finished, you can then retry to elevate to $pretty_distro_name.

        EOS
        return 0;
    }

    WARN( <<~"EOS" );
    Prior to elevating this system to $pretty_distro_name,
    we will automatically upgrade your installation of $db_type
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
            The system cannot be elevated to $pretty_distro_name until $db_type has been upgraded. To upgrade manually:

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
        return $self->has_blocker(q[MySQL/MariaDB upgrade in progress. Please wait for the upgrade to finish.]);
    }

    return 0;
}

sub _warning_mysql_not_enabled ($self) {
    require Cpanel::Services::Enabled;
    my $enabled = Cpanel::Services::Enabled::is_enabled('mysql');

    Elevate::StageFile::update_stage_file( { 'mysql-enabled' => $enabled } );
    WARN( "$db_type is disabled. This must be enabled for the upgrade to succeed.\n" . "We temporarily will enable it when it is needed to be enabled,\n" . "but we recommend starting the process with $db_type enabled." ) if !$enabled;
    return 0;
}

1;
