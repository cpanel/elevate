package Elevate::Components::UpdateSystem;

=encoding utf-8

=head1 NAME

Elevate::Components::UpdateSystem

=head2 check

Ensure that the Package System is in an operable state.

=head2 pre_distro_upgrade

Ensure that all system packages are up to date

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::OS ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub check ($self) {
    $self->_check_cpanel_pkgs();
    return;
}

sub _check_cpanel_pkgs ($self) {
    my $out = $self->ssystem_capture_output( '/usr/local/cpanel/scripts/check_cpanel_pkgs', '--list-only' );

    if ( $out->{'status'} != 0 ) {
        my $altered = join "\n", @{ $out->{stdout} };

        WARN( <<~"EOS" );
        /usr/local/cpanel/scripts/check_cpanel_pkgs reported that your system
        has altered packages.

        $altered

        Running check_cpanel_pkgs with the fix arguent should correct the issue.

        Example: /usr/local/cpanel/scripts/check_cpanel_pkgs --fix

        EOS
    }

    # invert to account for system exit codes
    return $out->{status} ? 0 : 1;
}

sub pre_distro_upgrade ($self) {
    Elevate::PkgMgr::clean_all();

    my $ok = $self->_check_cpanel_pkgs();
    $self->_fix_cpanel_pkgs() if !$ok;

    $self->ssystem_and_die(qw{/scripts/update-packages});

    # Remove this file so that nothing gets held back here since we need
    # to make sure that everything can update before we attempt to upgrade
    # the server
    # NOTE: This has to happen after update-packages or update-packages
    #       will put it back in place
    if ( Elevate::OS::is_apt_based() ) {
        INFO('Removing /etc/apt/preferences.d/99-cpanel-exclude-packages');
        unlink('/etc/apt/preferences.d/99-cpanel-exclude-packages');
    }

    Elevate::PkgMgr::update();

    return;
}

sub _fix_cpanel_pkgs ($self) {
    $self->ssystem(qw{/usr/local/cpanel/scripts/check_cpanel_pkgs --fix});

    my $out = $self->ssystem_capture_output(
        '/usr/local/cpanel/scripts/check_cpanel_pkgs',
        '--list-only'
    );

    if ( $out->{status} != 0 ) {
        my $altered = join "\n", @{ $out->{stdout} };

        LOGDIE( <<~"EOS" );
        /usr/local/cpanel/scripts/check_cpanel_pkgs was unable to repair the packages on this system:

        $altered

        You may be able to resolve this by executing

        /usr/local/cpanel/scripts/check_cpanel_pkgs --fix

        Once the issue has been resolved, you may continue this process with

        $0 --continue
        EOS

    }

    return;
}

1;
