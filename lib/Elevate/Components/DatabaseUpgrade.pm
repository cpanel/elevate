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

sub pre_distro_upgrade ($self) {

    # We don't auto-upgrade the database if provided by cloudlinux
    return if Elevate::Database::is_database_provided_by_cloudlinux();

    $self->_ensure_localhost_mysql_profile_is_active(1);

    # If the database version is supported on the new OS version, then no need to upgrade
    return if Elevate::Database::is_database_version_supported( Elevate::Database::get_local_database_version() );

    Elevate::Database::upgrade_database_server();

    return;
}

sub post_distro_upgrade ($self) {
    return unless -e MYSQL_PROFILE_FILE;

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

    unlink MYSQL_PROFILE_FILE or WARN( "Could not delete " . MYSQL_PROFILE_FILE . ": $!" );

    return;
}

sub _ensure_localhost_mysql_profile_is_active ( $self, $should_create_localhost_profile ) {
    return if Cpanel::MysqlUtils::MyCnf::Basic::is_local_mysql();

    my $profile_manager = Cpanel::MysqlUtils::RemoteMySQL::ProfileManager->new();

    # Immediately record the currently active profile, as othrewise you can
    # miss it in the try/catch below. Default to localhost, because if there's
    # no answer, something's probably wrong in a way we don't *want* to touch.
    my $profile = $profile_manager->get_active_profile('dont_die') || 'localhost';
    if ($should_create_localhost_profile) {
        INFO( "Saving the currently active MySQL Profile ($profile) to " . MYSQL_PROFILE_FILE );
        File::Slurper::write_text( MYSQL_PROFILE_FILE, $profile );
    }

    # Validate that the current “localhost” profile exists, and contains valid settings.
    try {
        $profile_manager->validate_profile('localhost');
        $self->_activate_localhost_profile($profile_manager);
    }

    # Otherwise attempt to recreate it, overwriting the existing profile.
    catch {
        die "Unable to generate/enable localhost MySQL profile: $_\n" unless $should_create_localhost_profile;
        INFO("Attempting to create new localhost MySQL profile...");
        $self->_create_new_localhost_profile($profile_manager);
        $self->_ensure_localhost_mysql_profile_is_active(0);
    };

    return;
}

sub _create_new_localhost_profile ( $self, $profile_manager ) {

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
    INFO("Resetting password for local root database user...");

    my $encoded_password = Cpanel::Encoder::URI::uri_encode_str($password);

    my $output = Cpanel::SafeRun::Simple::saferunnoerror( q{/bin/sh}, q{-c}, qq{/usr/local/cpanel/bin/whmapi1 --output=json set_local_mysql_root_password password='$encoded_password'} );
    my $result = eval { Cpanel::JSON::Load($output); } // {};

    unless ( $result->{metadata}{result} ) {

        my $errors = join qq{\n\n}, @{ $result->{'metadata'}{'errors'} };

        die <<~"EOS";
        Unable to set root password for the localhost database server.

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
        Unable to activate a MySQL profile for "localhost":

        $stdout

        Please resolve the reported problems then run this script again with:

        /scripts/elevate-cpanel --continue

        EOS
    }

    return;
}

1;
