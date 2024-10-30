package Elevate::Components::UpdateSystem;

=encoding utf-8

=head1 NAME

Elevate::Components::UpdateSystem

=head2 check

noop

=head2 pre_distro_upgrade

Ensure that all system packages are up to date

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::OS ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {
    Elevate::PkgMgr::clean_all();
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

1;
