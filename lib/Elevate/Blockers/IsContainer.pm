package Elevate::Blockers::IsContainer;

=encoding utf-8

=head1 NAME

Elevate::Blockers::IsContainer

Blocker to check if this is run on a container.

=cut

use cPstrict;

use parent        qw{Elevate::Blockers::Base};
use Log::Log4perl qw(:easy);

sub check ($self) {    # $self is a cpev object here

    return 0 unless $self->should_run_distro_upgrade;

    if ( _is_container_envtype() ) {
        return $self->has_blocker( <<~'EOS');
        cPanel thinks that this is a container-like environment.
        This cannot be upgraded by the native leapp tool.
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
