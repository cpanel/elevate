package Elevate::Components::MySQL;

=encoding utf-8

=head1 NAME

Elevate::Components::MySQL

Capture and reinstall MySQL packages.

=cut

use cPstrict;

use File::Copy    ();
use Log::Log4perl qw(:easy);

use Elevate::Database ();
use Elevate::Notify   ();

use parent qw{Elevate::Components::Base};

my $cnf_file = '/etc/my.cnf';

sub pre_leapp ($self) {

    Elevate::Database::is_database_provided_by_cloudlinux()
      ? $self->run_once('_remove_cpanel_mysql_packages')
      : $self->run_once("_cleanup_mysql_packages");

    return;
}

sub post_leapp ($self) {
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    $self->run_once('_reinstall_mysql_packages');

    return;
}

sub _cleanup_mysql_packages ($self) {

    my $mysql_version = cpev::read_stage_file( 'mysql-version', '' );
    return unless length $mysql_version;

    INFO("# Cleanup MySQL packages ; using version $mysql_version");

    cpev::update_stage_file( { 'mysql-version' => $mysql_version } );

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

    my $mysql_version = cpev::read_stage_file( 'mysql-version', '' ) or return;
    my $enabled       = cpev::read_stage_file( 'mysql-enabled', '' ) or return;

    INFO("Restoring MySQL $mysql_version");

    my ( $major, $minor ) = split( /\./, $mysql_version );

    # Try to restore any .rpmsave'd configs before we reinstall
    # It *should be here* given we put it there, so no need to do a -f/-s check
    INFO("Restoring $cnf_file.rpmsave_pre_elevate to $cnf_file...");
    File::Copy::copy( "$cnf_file.rpmsave_pre_elevate", $cnf_file ) or WARN("Couldn't restore $cnf_file.rpmsave: $!");

    if ( !$enabled ) {
        INFO("MySQL is not enabled. This will cause the MySQL upgrade tool to fail. Temporarily enabling it to ensure the upgrade succeeds.");
        Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 configureservice service=mysql enabled=1});

        # Pray it goes ok, as what exactly do you want me to do if this reports failure? May as well just move forward in this case without checking.
    }

    my $out = Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade}, "version=$mysql_version" );
    die qq[Failed to restore MySQL $mysql_version] if $?;

    if ( $out =~ m{\supgrade_id:\s*(\S+)} ) {
        my $id = $1;

        INFO("Restoring MySQL via upgrade_id $id");
        INFO('Waiting for MySQL installation');

        my $status = '';

        my $c = 0;

        my $wait_more = 30;
        while (1) {
            $c   = ( $c + 1 ) % 10;
            $out = Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/local/cpanel/bin/whmapi1 background_mysql_upgrade_status }, "upgrade_id=$id" );
            if ($?) {
                last if !$enabled;
                die qq[Failed to restore MySQL $mysql_version: cannot check upgrade_id=$id];
            }

            if ( $out =~ m{\sstate:\s*inprogress} ) {
                print ".";
                print "\n" if $c == 0;
                sleep 5;
                next;
            }

            if ( $out =~ m{\sstate:\s*(\w+)} ) {
                $status = $1;
            }

            # we cannot trust the whmapi1 call (race condition) CPANEL-43253
            if ( $status ne 'success' && --$wait_more > 0 ) {
                sleep 1;
                next;
            }

            last;
        }

        print "\n"                                                                                                          if $c;          # clear the last "." from above
        Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/local/cpanel/bin/whmapi1 configureservice service=mysql enabled=0}) if !$enabled;

        if ( $status eq 'success' ) {
            INFO("MySQL $mysql_version restored");
        }
        else {
            my $msg = "Failed to restore MySQL $mysql_version: upgrade $id status '$status'";

            FATAL($msg);
            FATAL("$out");

            Elevate::Notify::add_final_notification($msg);
            return;
        }
    }
    else {
        die qq[Cannot find upgrade_id from start_background_mysql_upgrade:\n$out];
    }

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
