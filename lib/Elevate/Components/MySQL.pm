package Elevate::Components::MySQL;

=encoding utf-8

=head1 NAME

Elevate::Components::MySQL

=head2 check

Determine if the current database version is supported after the upgrade.
Determine if a database upgrade is in progress.  Determine if the database
server is enabled.

=head2 pre_distro_upgrade

Remove database packages

=head2 post_distro_upgrade

Install database packages

=cut

use cPstrict;

use Try::Tiny;

use File::Copy    ();
use Log::Log4perl qw(:easy);

use Cpanel::OS                         ();
use Cpanel::Pkgr                       ();
use Cpanel::Version::Tiny              ();
use Cpanel::JSON                       ();
use Cpanel::SafeRun::Simple            ();
use Cpanel::DB::Map::Collection::Index ();
use Cpanel::Exception                  ();
use Cpanel::MysqlUtils::MyCnf::Basic   ();
use Cpanel::MysqlUtils::Running        ();

use Elevate::Database  ();
use Elevate::Notify    ();
use Elevate::PkgMgr    ();
use Elevate::StageFile ();

use parent qw{Elevate::Components::Base};

my $cnf_file = '/etc/my.cnf';

sub pre_distro_upgrade ($self) {
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    $self->run_once("_cleanup_mysql_packages");
    return;
}

sub post_distro_upgrade ($self) {
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    $self->run_once('_reinstall_mysql_packages');

    return;
}

sub _cleanup_mysql_packages ($self) {

    my $mysql_version = Elevate::StageFile::read_stage_file( 'mysql-version', '' );
    return unless length $mysql_version;

    my $db_type = Elevate::Database::get_database_type_name_from_version($mysql_version);
    INFO("# Cleanup $db_type packages ; using version $mysql_version");

    Elevate::StageFile::update_stage_file( { 'mysql-version' => $mysql_version } );

    # Stash current config so we can restore it later.
    File::Copy::cp( $cnf_file, "$cnf_file.rpmsave_pre_elevate" ) or WARN("Couldn't backup $cnf_file to $cnf_file.rpmsave_pre_elevate: $!");

    # make sure all packages from unsupported repo are removed
    #
    # we cannot only remove the packages for the current MySQL versions
    # some packages can also installed from other repo
    #
    # This is not necessary on apt based systems since it is better
    # able to handle the upgrade than leapp/rhel based systems

    $self->_remove_cpanel_mysql_packages() unless Elevate::OS::is_apt_based();

    return;
}

sub _remove_cpanel_mysql_packages ($self) {
    $self->_cleanup_mysql_57_packages();
    $self->_cleanup_mysql_80_packages();
    $self->_cleanup_mysql_102_packages();
    $self->_cleanup_mysql_103_packages();
    $self->_cleanup_mysql_105_packages();
    $self->_cleanup_mysql_106_packages();

    return;
}

sub _reinstall_mysql_packages {

    my $upgrade_version     = Elevate::StageFile::read_stage_file( 'mysql-version', '' ) or return;
    my $upgrade_dbtype_name = Elevate::Database::get_database_type_name_from_version($upgrade_version);
    my $enabled             = Elevate::StageFile::read_stage_file( 'mysql-enabled', '' ) or return;

    INFO("Restoring $upgrade_dbtype_name $upgrade_version");

    if ( !$enabled ) {
        INFO("$upgrade_dbtype_name is not enabled. This will cause the $upgrade_dbtype_name upgrade tool to fail. Temporarily enabling it to ensure the upgrade succeeds.");
        Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 configureservice service=mysql enabled=1});

        # Pray it goes ok, as what exactly do you want me to do if this reports failure? May as well just move forward in this case without checking.
    }

    try {
        Elevate::Database::upgrade_database_server();
    }
    catch {
        LOGDIE( <<~"EOS" );
        Unable to install $upgrade_dbtype_name $upgrade_version.  To attempt to
        install the database server manually, execute:

        /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=$upgrade_version

        To have this script attempt to install $upgrade_dbtype_name $upgrade_version
        for you, execute this script again with the continue flag

        /scripts/elevate-cpanel --continue

        Or once the issue has been resolved manually, execute

        /scripts/elevate-cpanel --continue

        to complete the ELevation process.
        EOS
    };

    # No point in restoring my.cnf if the database service is disabled
    if ( !$enabled ) {
        Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 configureservice service=mysql enabled=0});
        return;
    }

    # In case the pre elevate file causes issues for whatever reason
    File::Copy::cp( $cnf_file, "$cnf_file.elevate_post_distro_upgrade_orig" );

    # Try to restore any .rpmsave'd configs after we reinstall
    # It *should be here* given we put it there, so no need to do a -f/-s check
    INFO("Restoring $cnf_file.rpmsave_pre_elevate to $cnf_file...");
    File::Copy::cp( "$cnf_file.rpmsave_pre_elevate", $cnf_file );

    # Return if MySQL restarts successfully
    my $restart_out   = Cpanel::SafeRun::Simple::saferunnoerror(qw{/scripts/restartsrv_mysql});
    my @restart_lines = split "\n", $restart_out;

    DEBUG('Restarting Database server with restored my.cnf in place');
    DEBUG($restart_out);
    return if grep { $_ =~ m{mysql (?:re)?started successfully} } @restart_lines;

    # The database server is not able to start with the pre_distro_upgrade version of
    # my.cnf in place.  Revert to the standard one that was created
    # in the post_distro_upgrade restore
    INFO('The database server failed to start.  Restoring my.cnf to default.');
    File::Copy::cp( "$cnf_file.elevate_post_distro_upgrade_orig", $cnf_file );

    $restart_out   = Cpanel::SafeRun::Simple::saferunnoerror(qw{/scripts/restartsrv_mysql});
    @restart_lines = split "\n", $restart_out;

    DEBUG('Restarting Database server with original my.cnf in place');
    DEBUG($restart_out);
    return if grep { $_ =~ m{mysql (?:re)?started successfully} } @restart_lines;

    # If the database server is still unable to start, die as this
    # component likely failed with an unexpected/unknown error
    LOGDIE( <<~'EOS' );
    The database server was unable to start after the attempted restoration.

    Check the elevate log located at '/var/log/elevate-cpanel.log' for further
    details.

    Additionally, you may wish to inspect the database error log for further
    details.  This log is located at '/var/lib/mysql/$HOSTNAME.err' where
    $HOSTNAME is the hostname of your server by default.
    EOS

    return;
}

sub _cleanup_mysql_57_packages ($self) {
    my @repos = qw{
      Mysql-connectors-community
      Mysql-tools-community
      Mysql57-community
      Mysql-tools-preview
    };

    Elevate::PkgMgr::remove_pkgs_from_repos(@repos);

    return;
}

sub _cleanup_mysql_80_packages ($self) {

    my @repos = qw{
      Mysql-connectors-community
      Mysql-tools-community
      Mysql80-community
      Mysql-tools-preview
    };

    Elevate::PkgMgr::remove_pkgs_from_repos(@repos);

    return;
}

sub _cleanup_mysql_102_packages ($self) {

    Elevate::PkgMgr::remove_pkgs_from_repos('MariaDB102');

    return;
}

sub _cleanup_mysql_103_packages ($self) {

    Elevate::PkgMgr::remove_pkgs_from_repos('MariaDB103');

    return;
}

sub _cleanup_mysql_105_packages ($self) {

    Elevate::PkgMgr::remove_pkgs_from_repos('MariaDB105');

    return;
}

sub _cleanup_mysql_106_packages ($self) {

    Elevate::PkgMgr::remove_pkgs_from_repos('MariaDB106');

    return;
}

sub check ($self) {
    my $ok = 1;
    $ok = 0 unless $self->_blocker_old_mysql;
    $ok = 0 unless $self->_blocker_mysql_upgrade_in_progress;
    $ok = 0 unless $self->_blocker_mysql_database_corrupted;
    $self->_warning_mysql_not_enabled();
    return $ok;
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

    my $db_version = Elevate::Database::get_local_database_version();

    # If we are running a local version of MySQL/MariaDB that will be
    # supported by the new OS version, we leave it as it is.
    if ( Elevate::Database::is_database_version_supported($db_version) ) {

        # store the MySQL version we started from
        Elevate::StageFile::update_stage_file( { 'mysql-version' => $db_version } );
        return 0;
    }

    my $pretty_distro_name  = Elevate::OS::upgrade_to_pretty_name();
    my $db_type             = Elevate::Database::get_database_type_name_from_version($db_version);
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

sub _blocker_mysql_database_corrupted ($self) {

    return 0 if $self->is_check_mode();

    # Do not perform this check for remote mysql
    return 0 unless Cpanel::MysqlUtils::MyCnf::Basic::is_local_mysql();

    # We cannot run mysqlcheck if mysql is not running
    if ( !Cpanel::MysqlUtils::Running::is_mysql_running() ) {

        # No blocker if it is not running because it is not enabled
        # No need to check the database integrity if MySQL is disabled
        return 0 unless Cpanel::Services::Enabled::is_enabled('mysql');

        my $output = $self->ssystem_capture_output(qw{/scripts/restartsrv_mysql});

        WARN('Database server was down, starting it to check database integrity');
        unless ( Cpanel::MysqlUtils::Running::is_mysql_running()
            && grep { /mysql (?:re)?started successfully/ } @{ $output->{stdout} } ) {

            return $self->has_blocker( <<~"EOS" );
            Unable to to start the database server to check database integrity.  
            Additional information can be found in the error log located at /var/log/mysqld.log
            To attempt to start the database server, execute: /scripts/restartsrv_mysql
            EOS
        }
    }

    # Perform a medium check on all databases and only output errors
    my $mysqlcheck_path = Cpanel::Binaries::path('mysqlcheck');
    my $output          = $self->ssystem_capture_output( $mysqlcheck_path, '-c', '-m', '-A', '--silent' );

    # mysqlcheck doesn't return an error code
    # We check for lines that actually begin with "Error" (or "error")
    # because we don't want to block of only warnings are found
    if ( scalar grep { /^error/i } @{ $output->{stdout} } ) {

        my $issues_found = join( "\n", @{ $output->{stdout} } );
        return $self->has_blocker( <<~"EOS" );
            We have found the following problems with your database(s):
            $issues_found
            You should repair any corrupted databases before elevating the system.
            EOS
    }

    return 0;
}

sub _warning_mysql_not_enabled ($self) {
    require Cpanel::Services::Enabled;
    my $enabled = Cpanel::Services::Enabled::is_enabled('mysql');

    Elevate::StageFile::update_stage_file( { 'mysql-enabled' => $enabled } );

    if ( !$enabled ) {
        my $db_version = Elevate::Database::get_local_database_version();
        my $db_type    = Elevate::Database::get_database_type_name_from_version($db_version);
        WARN( "$db_type is disabled. This must be enabled for the upgrade to succeed.\n" . "We temporarily will enable it when it is needed to be enabled,\n" . "but we recommend starting the process with $db_type enabled." );
    }

    return 0;
}

1;
