package Elevate::Components::MySQL;

=encoding utf-8

=head1 NAME

Elevate::Components::MySQL

Capture and reinstall MySQL packages.

=cut

use cPstrict;

use File::Copy    ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

my $cnf_file = '/etc/my.cnf';
sub pre_leapp ($self) {

    $self->run_once("_cleanup_mysql_packages");

    return;
}

sub post_leapp ($self) {

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

    INFO("Restoring MySQL $mysql_version");

    my ( $major, $minor ) = split( /\./, $mysql_version );

    # Try to restore any .rpmsave'd configs before we reinstall
    # It *should be here* given we put it there, so no need to do a -f/-s check
    INFO("Restoring $cnf_file.rpmsave_pre_elevate to $cnf_file...");
    File::Copy::copy( "$cnf_file.rpmsave_pre_elevate", $cnf_file ) or WARN("Couldn't restore $cnf_file.rpmsave: $!");

    my $out = Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade}, "version=$mysql_version" );
    die qq[Failed to restore MySQL $mysql_version] if $?;

    if ( $out =~ m{\supgrade_id:\s*(\S+)} ) {
        my $id = $1;

        INFO("Restoring MySQL via upgrade_id $id");
        INFO('Waiting for MySQL installation');

        my $status = '';

        my $c = 0;

        while (1) {
            $c   = ( $c + 1 ) % 10;
            $out = Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/local/cpanel/bin/whmapi1 background_mysql_upgrade_status }, "upgrade_id=$id" );
            die qq[Failed to restore MySQL $mysql_version: cannot check upgrade_id=$id] if $?;

            if ( $out =~ m{\sstate:\s*inprogress} ) {
                print ".";
                print "\n" if $c == 0;
                sleep 5;
                next;
            }

            if ( $out =~ m{\sstate:\s*(\w+)} ) {
                $status = $1;
            }
            last;
        }

        print "\n" if $c;    # clear the last "." from above

        if ( $status eq 'success' ) {
            INFO("MySQL $mysql_version restored");
        }
        else {
            FATAL("Failed to restore MySQL $mysql_version: upgrade $id status '$status'");
            FATAL("$out");
            die 'Failed to restore MySQL';
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
