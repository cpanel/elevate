package Elevate::Components::MySQL;

=encoding utf-8

=head1 NAME

Elevate::Components::MySQL

Capture and reinstall MySQL packages.

=cut

use cPstrict;

use Try::Tiny;

use File::Copy    ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON ();

use Elevate::Database  ();
use Elevate::Notify    ();
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
    File::Copy::copy( $cnf_file, "$cnf_file.rpmsave_pre_elevate" ) or WARN("Couldn't backup $cnf_file to $cnf_file.rpmsave_pre_elevate: $!");

    # make sure all packages from unsupported repo are removed
    #
    # we cannot only remove the packages for the current MySQL versions
    # some packages can also installed from other repo

    $self->_remove_cpanel_mysql_packages();

    return;
}

=head2

MySQL Governor will leave the repo files for MySQL/MariaDB versions provided by
cPanel.  Since the repo files are owned by a package and it is not necessary for
them to be installed in order to reinstall cPanel MySQL/MariaDB, it is safe to
remove them.  CL leapp will inhibit based on these files being in place, so it
is also necessary to remove them.

=cut

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
    File::Copy::copy( $cnf_file, "$cnf_file.elevate_post_distro_upgrade_orig" );

    # Try to restore any .rpmsave'd configs after we reinstall
    # It *should be here* given we put it there, so no need to do a -f/-s check
    INFO("Restoring $cnf_file.rpmsave_pre_elevate to $cnf_file...");
    File::Copy::copy( "$cnf_file.rpmsave_pre_elevate", $cnf_file );

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
    File::Copy::copy( "$cnf_file.elevate_post_distro_upgrade_orig", $cnf_file );

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

    $self->remove_rpms_from_repos(@repos);

    return;
}

sub _cleanup_mysql_80_packages ($self) {

    my @repos = qw{
      Mysql-connectors-community
      Mysql-tools-community
      Mysql80-community
      Mysql-tools-preview
    };

    $self->remove_rpms_from_repos(@repos);

    return;
}

sub _cleanup_mysql_102_packages ($self) {

    $self->remove_rpms_from_repos('MariaDB102');

    return;
}

sub _cleanup_mysql_103_packages ($self) {

    $self->remove_rpms_from_repos('MariaDB103');

    return;
}

sub _cleanup_mysql_105_packages ($self) {

    $self->remove_rpms_from_repos('MariaDB105');

    return;
}

sub _cleanup_mysql_106_packages ($self) {

    $self->remove_rpms_from_repos('MariaDB106');

    return;
}

1;
