package Elevate::Components::DatabaseUpgrade;

=encoding utf-8
=head1 NAME

Elevate::Components::DatabaseUpgrade

Handle auto-upgrades for outdated versions of MySQL/MariaDB

=cut

use cPstrict;

use Elevate::Database ();

use parent qw{Elevate::Components::Base};

use Cpanel::MysqlUtils::RemoteMySQL::ProfileManager ();

use File::Slurper;
use Try::Tiny;

use Cpanel::MysqlUtils::MyCnf::Basic                ();
use Cpanel::MysqlUtils::RemoteMySQL::ProfileManager ();
use Cpanel::PasswdStrength::Generate                ();
use Cpanel::JSON                                    ();
use Cpanel::SafeRun::Simple                         ();
use Cpanel::Encoder::URI                            ();

use constant MYSQL_PROFILE_FILE => '/var/cpanel/elevate-mysql-profile';

use Log::Log4perl qw(:easy);

sub pre_leapp ($self) {

    # We don't auto-upgrade the database if provided by cloudlinux
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    # If the database version is supported on the new OS version, then no need to upgrade
    return if Elevate::Database::is_database_version_supported( Elevate::Database::get_local_database_version() );

    $self->_ensure_localhost_mysql_profile_is_active(1);

    Elevate::Database::upgrade_database_server();

    return;
}

sub post_leapp ($self) {

    if ( -e MYSQL_PROFILE_FILE ) {
        my $original_profile = File::Slurper::read_text(MYSQL_PROFILE_FILE) // 'localhost';
        INFO(qq{Reactivating "$original_profile" MySQL profile});

        my $output = $self->ssystem_capture_output( '/usr/local/cpanel/scripts/manage_mysql_profiles', '--activate', "$original_profile" );
        my $stdout = join qq{\n}, @{ $output->{'stdout'} };

        unless ( $stdout =~ m{MySQL profile activation done} ) {
            die <<~"EOS";
            Unable to reactivate the original remote MySQL profile "$original_profile":

            $stdout

            Please resolve the reported problems then run this script again with:

            /scripts/elevate-cpanel --continue

            EOS
        }

        unlink MYSQL_PROFILE_FILE;
    }

    return;
}

sub _ensure_localhost_mysql_profile_is_active ( $self, $should_create_localhost_profile ) {

    if ( Cpanel::MysqlUtils::MyCnf::Basic::is_local_mysql() ) {
        return;
    }

    my $profile_manager = Cpanel::MysqlUtils::RemoteMySQL::ProfileManager->new();

    # Validate that the current “localhost” profile exists, and contains valid settings.
    try {
        $profile_manager->validate_profile('localhost');
        $self->_activate_localhost_profile($profile_manager);
    }

    # Otherwise attempt to recreate it, overwriting the existing profile.
    catch {
        if ($should_create_localhost_profile) {
            INFO("Attempting to create new localhost MySQL profile...");
            $self->_create_new_localhost_profile($profile_manager);
            $self->_ensure_localhost_mysql_profile_is_active(0);
        }
        else {
            die "Unable to generate/enable localhost MySQL profile: $_\n";
        }
    };

    return;
}

sub _create_new_localhost_profile ( $self, $profile_manager ) {

    my $active_profile = $profile_manager->get_active_profile('dont_die');
    File::Slurper::write_text( MYSQL_PROFILE_FILE, $active_profile );

    my $password = Cpanel::PasswdStrength::Generate::generate_password( 16, no_othersymbols => 1 );

    try {
        $profile_manager->create_profile(
            {
                'name'       => 'localhost',
                'mysql_user' => 'root',
                'mysql_pass' => $password,
                'mysql_host' => 'localhost',
                'mysql_port' => Cpanel::MysqlUtils::MyCnf::Basic::getmydbport('root') || 3306,
                'setup_via'  => 'Auto-generated localhost profile during elevate.',
            },
            { 'overwrite' => 1 },
        );
    }
    catch {
        die <<~"EOS";
        Unable to generate a functioning MySQL DB profile for the local MySQL server.

        The following error was encountered:

        $@
        EOS
    };

    $self->_set_local_mysql_root_password($password);

    $profile_manager->save_changes_to_disk();

    $self->_activate_localhost_profile($profile_manager);

    return;
}

sub _set_local_mysql_root_password ( $self, $password ) {
    INFO("Resetting password for local root MySQL user...");

    my $encoded_password = Cpanel::Encoder::URI::uri_encode_str($password);

    my $output = Cpanel::SafeRun::Simple::saferunnoerror( q{/bin/sh}, q{-c}, qq{/usr/local/cpanel/bin/whmapi1 --output=json set_local_mysql_root_password password='$encoded_password'} );
    my $result = eval { Cpanel::JSON::Load($output); } // {};

    unless ( $result->{metadata}{result} ) {

        my $errors = join qq{\n\n}, @{ $result->{'metadata'}{'errors'} };

        die <<~"EOS";
        Unable to set root password for the localhost MySQL server.

        The following errors occurred:

        $errors

        Please resolve the reported problems then run this script again with:

        /scripts/elevate-cpanel --continue

        EOS
    }

    return;
}

sub _activate_localhost_profile {
    my ( $self, $profile_manager ) = @_;

    if ($profile_manager) {
        $profile_manager->{'_transaction_obj'}->close_or_die();
    }

    INFO("Activating “localhost” MySQL profile");

    my $output = $self->ssystem_capture_output(qw{/usr/local/cpanel/scripts/manage_mysql_profiles --activate localhost});
    my $stdout = join qq{\n}, @{ $output->{'stdout'} };

    if ( $stdout !~ m{MySQL profile activation done} ) {
        die <<~"EOS";
        Unable to activate a MySQL DB profile for "localhost":

        $stdout

        Please resolve the reported problems then run this script again with:

        /scripts/elevate-cpanel --continue

        EOS
    }

    return;
}

1;
