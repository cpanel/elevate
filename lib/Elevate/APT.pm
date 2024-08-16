package Elevate::APT;

=encoding utf-8

=head1 NAME

Elevate::APT

Logic wrapping the 'apt' system binary

=cut

use cPstrict;

use constant APT      => q[/usr/bin/apt];
use constant APT_MARK => q[/usr/bin/apt-mark];

use constant APT_NON_INTERACTIVE_ARGS => qw{
  -o Dpkg::Options::=--force-confdef
  -o Dpkg::Options::=--force-confold
};

use Simple::Accessor qw{
  cpev
};

sub _build_cpev {
    die q[Missing cpev];
}

sub upgrade_all ($self) {
    my @apt_args = '-y';
    push @apt_args, APT_NON_INTERACTIVE_ARGS;
    $self->cpev->ssystem_and_die( APT, @apt_args, 'upgrade' );
    return;
}

sub update ($self) {
    $self->cpev->ssystem_and_die( { should_hide_output => 1 }, APT, 'update' );
    return;
}

sub showhold ($self) {
    return $self->cpev->ssystem_hide_and_capture_output( APT_MARK, 'showhold' );
}

1;
