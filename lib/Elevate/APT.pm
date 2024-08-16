package Elevate::APT;

=encoding utf-8

=head1 NAME

Elevate::APT

Logic wrapping the 'apt' system binary

=cut

use cPstrict;

use constant APT      => q[/usr/bin/apt];
use constant APT_MARK => q[/usr/bin/apt-mark];

use Simple::Accessor qw{
  cpev
};

sub _build_cpev {
    die q[Missing cpev];
}

sub update ($self) {
    $self->cpev->ssystem_and_die( { should_hide_output => 1 }, APT, 'update' );
    return;
}

sub showhold ($self) {
    return $self->cpev->ssystem_hide_and_capture_output( APT_MARK, 'showhold' );
}

1;
