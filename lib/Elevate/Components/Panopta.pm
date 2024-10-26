package Elevate::Components::Panopta;

=encoding utf-8

=head1 NAME

Elevate::Components::Panopta

=head2 check

noop

=head2 pre_distro_upgrade

Uninstall the Panopta agent since it is deprecated and not compatible with
Elevate

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Cpanel::Pkgr ();

use Elevate::PkgMgr ();

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    if ( Cpanel::Pkgr::is_installed('panopta-agent') ) {

        Elevate::PkgMgr::remove('panopta-agent');
    }

    return;
}

1;
