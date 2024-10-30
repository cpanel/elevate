package Elevate::Components::Softaculous;

=encoding utf-8

=head1 NAME

Elevate::Components::Softaculous

=head2 pre_distro_upgrade

If we can query the version of Softaculous through their CLI tool, it is installed.

=head2 post_distro_upgrade

If Softaculous is installed, re-install it after the upgrade.

NOTE: This needs to happen after cPanel is updated to work with the new OS, since Softaculous relies on cPanel PHP.

=cut

use cPstrict;

use Elevate::Fetch     ();
use Elevate::StageFile ();

use Cpanel::Binaries        ();
use Cpanel::SafeRun::Object ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use Simple::Accessor qw(cli_path);

sub _build_cli_path { return '/usr/local/cpanel/whostmgr/docroot/cgi/softaculous/cli.php' }

sub pre_distro_upgrade ($self) {

    return unless -r $self->cli_path;

    my $sr = _run_script( $self->cli_path );

    return if $sr->exec_failed() || $sr->to_exception();

    my $version = $sr->stdout() // '';
    chomp $version;

    if ( length $version ) {
        INFO('Softaculous has been detected. The system will re-install that software after the distro upgrade.');
        Elevate::StageFile::update_stage_file( { softaculous => $version } );
    }

    return;
}

# split out for mocking purposes
sub _run_script ($path) {
    return Cpanel::SafeRun::Object->new(
        program => Cpanel::Binaries::path('php'),
        args    => [ $path, '--version' ],
    );
}

sub post_distro_upgrade ($self) {

    my $version = Elevate::StageFile::read_stage_file( 'softaculous', '' );
    return unless length $version;

    my $path = Elevate::Fetch::script( 'https://files.softaculous.com/install.sh', 'softaculous_install' );

    if ($path) {
        INFO('Re-installing Softaculous:');
        if ( $self->ssystem( Cpanel::Binaries::path('bash'), $path, '--reinstall' ) ) {
            ERROR('Re-installation of Softaculous failed.');
        }
    }
    else {
        ERROR('Failed to download Softaculous installer.');
    }

    return;
}

1;
