package Elevate::Components::Base;

=encoding utf-8

=head1 NAME

Elevate::Components::Base

This is the base class to any components used by the elevate script.

A component allows to group together some actions which need to be performed
before / after the elevation process.

=cut

use cPstrict;

use Simple::Accessor qw(
  cpev
);

use Log::Log4perl qw(:easy);

# delegate to cpev
BEGIN {
    my @_DELEGATE_TO_CPEV = qw{
      getopt
      update_stage_file
      upgrade_to_rocky
      upgrade_to_pretty_name
      tmp_dir
      ssystem
      ssystem_and_die
      ssystem_capture_output
      remove_rpms_from_repos
    };

    foreach my $subname (@_DELEGATE_TO_CPEV) {
        no strict 'refs';
        *$subname = sub ( $self, @args ) {
            my $cpev = $self->cpev;
            if(defined $cpev) {
              my $sub  = $cpev->can($subname) or die qq[cpev does not support $subname];
              return $sub->( $cpev, @args );
            } else {
              die "cpev $subname not available";
            }
        }
    }
}

sub run_once ( $self, $subname ) {

    my $cpev     = $self->cpev;
    my $run_once = $cpev->can('run_once') or die qq[cpev does not support 'run_once'];

    my $label = ref($self) . "::$subname";

    my $sub = $self->can($subname) or die qq[$self does not support '$subname'];

    my $code = sub {
        return $sub->($self);
    };

    return $run_once->( $cpev, $label, $code );
}

1;
