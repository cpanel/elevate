package Elevate::YUM;

=encoding utf-8

=head1 NAME

Elevate::YUM

Logic wrapping the 'yum' system binary

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use Simple::Accessor qw{
  cpev
  pkgmgr
};

sub _build_cpev {
    die q[Missing cpev];
}

sub _build_pkgmgr {
    return '/usr/bin/yum';
}

sub remove ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem_and_die( $pkgmgr, '-y', 'remove', @pkgs );

    return;
}

sub clean_all ($self) {
    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem( $pkgmgr, 'clean', 'all' );

    return;
}

sub install_rpm_via_url ( $self, $rpm_url ) {
    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem_and_die( $pkgmgr, '-y', 'install', $rpm_url );

    return;
}

sub install ( $self, @pkgs ) {
    return unless scalar @pkgs;

    my $pkgmgr = $self->pkgmgr;

    $self->cpev->ssystem_and_die( $pkgmgr, '-y', 'install', @pkgs );

    return;
}

1;
