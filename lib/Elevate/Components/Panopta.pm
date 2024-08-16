package Elevate::Components::Panopta;

=encoding utf-8

=head1 NAME

Elevate::Components::Panopta

Handle situation where the Panopta agent is installed

Before leapp:
    Uninstall the Panopta agent since it is deprecated and
    not compatible with Elevate

=cut

use cPstrict;

use Cpanel::Pkgr ();

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    if ( Cpanel::Pkgr::is_installed('panopta-agent') ) {

        $self->yum->remove('panopta-agent');
    }

    return;
}

sub post_leapp ($self) {

    return;
}

1;
