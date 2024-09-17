package Elevate::Components::Panopta;

=encoding utf-8

=head1 NAME

Elevate::Components::Panopta

Handle situation where the Panopta agent is installed

Before distro upgrade:
    Uninstall the Panopta agent since it is deprecated and
    not compatible with Elevate

=cut

use cPstrict;

use Cpanel::Pkgr ();

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    if ( Cpanel::Pkgr::is_installed('panopta-agent') ) {

        $self->yum->remove('panopta-agent');
    }

    return;
}

sub post_distro_upgrade ($self) {

    return;
}

1;
