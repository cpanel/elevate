package Elevate::APT;

=encoding utf-8

=head1 NAME

Elevate::APT

Logic wrapping the 'apt' system binary

=cut

use cPstrict;

use constant APT      => q[/usr/bin/apt];
use constant APT_GET  => q[/usr/bin/apt-get];
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

sub install ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my @apt_args = (
        '-y',
        APT_NON_INTERACTIVE_ARGS,
    );

    $self->cpev->ssystem_and_die( APT_GET, @apt_args, 'install', @pkgs );
    return;
}

=head2 remove

Use purge instead of remove for apt to have similar behavior to yum/dnf

=cut

sub remove ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my @apt_args = (
        '-y',
        APT_NON_INTERACTIVE_ARGS,
    );

    $self->cpev->ssystem_and_die( APT_GET, @apt_args, 'purge', @pkgs );
    return;
}

sub upgrade_all ($self) {

    my @apt_args = (
        '-y',
        APT_NON_INTERACTIVE_ARGS,
    );

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

sub clean_all ($self) {
    $self->cpev->ssystem( APT_GET, 'clean' );
    return;
}

=head2 update_allow_erasing

Just an alias for upgrade_all in APT but needed for feature
compatibility with DNF

=cut

sub update_allow_erasing ( $self, @args ) {
    return $self->upgrade_all();
}

1;
