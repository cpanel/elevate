package Elevate::Blockers::IsContainer;

use cPstrict;

sub check ($self) {    # $self is a cpev object here
    if ( _is_container_envtype() ) {
        return $self->has_blocker( 90, "cPanel thinks that this is a container-like environment, which this script cannot support at this time." );
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
