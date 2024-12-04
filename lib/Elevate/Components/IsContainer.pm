package Elevate::Components::IsContainer;

=encoding utf-8

=head1 NAME

Elevate::Components::IsContainer

=head2 check

Prevent elevation if the server is hosted in a container like environment

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use parent        qw{Elevate::Components::Base};
use Log::Log4perl qw(:easy);

sub check ($self) {    # $self is a cpev object here

    return 0 unless $self->upgrade_distro_manually;

    if ( _is_container_envtype() ) {
        return $self->has_blocker( <<~'EOS');
        cPanel thinks that this is a container-like environment.
        This cannot be upgraded by this script.
        Consider contacting your hypervisor provider for alternative solutions.
        EOS
    }

    return 0;
}

sub _is_container_envtype () {
    require Cpanel::OSSys::Env;
    my $envtype = Cpanel::OSSys::Env::get_envtype();

    return scalar grep { $envtype eq $_ } qw(
      virtuozzo
      vzcontainer
      lxc
      virtualiron
      vserver
    );
}

1;
