package Elevate::Components::Base;

=encoding utf-8

=head1 NAME

Elevate::Components::Base

This is the base class to any components used by the elevate script.

A component allows to group together some actions which need to be performed
before / after the elevation process.

=cut

use cPstrict;

use Carp             ();
use Simple::Accessor qw(
  cpev
  rpm
  yum
  dnf
);

use Log::Log4perl qw(:easy);

# delegate to cpev
BEGIN {
    my @_DELEGATE_TO_CPEV = qw{
      getopt
      upgrade_to_pretty_name
      should_run_distro_upgrade
      ssystem
      ssystem_and_die
      ssystem_capture_output
      ssystem_hide_and_capture_output
      remove_rpms_from_repos
    };

    foreach my $subname (@_DELEGATE_TO_CPEV) {
        no strict 'refs';
        *$subname = sub ( $self, @args ) {
            my $cpev = $self->cpev          or Carp::confess(qq[Cannot find cpev to call $subname]);
            my $sub  = $cpev->can($subname) or Carp::confess(qq[cpev does not support $subname]);
            return $sub->( $cpev, @args );
        }
    }
}

sub _build_rpm ($self) {
    return Elevate::RPM->new( cpev => $self );
}

sub _build_yum ($self) {
    return Elevate::YUM->new( cpev => $self );
}

sub _build_dnf ($self) {
    return Elevate::DNF->new( cpev => $self );
}

sub run_once ( $self, $subname ) {

    my $cpev     = $self->cpev;
    my $run_once = $cpev->can('run_once') or Carp::confess(qq[cpev does not support 'run_once']);

    my $label = ref($self) . "::$subname";

    my $sub = $self->can($subname) or Carp::confess(qq[$self does not support '$subname']);

    my $code = sub {
        return $sub->($self);
    };

    return $run_once->( $cpev, $label, $code );
}

1;
