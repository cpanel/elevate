package Elevate::Components::RmMod;

=encoding utf-8

=head1 NAME

Elevate::Components::RmMod

Run rmmod

=cut

use cPstrict;

use Elevate::Constants ();

use Cwd           ();
use File::Copy    ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    $self->run_once("_rmod_ln");

    return;
}

sub _rmod_ln ($self) {

    $self->ssystem( '/usr/sbin/rmmod', $_ ) foreach qw/floppy pata_acpi/;

    return;
}

1;
