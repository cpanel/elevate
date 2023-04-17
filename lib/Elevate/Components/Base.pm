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
      run_once
    };

    foreach my $subname (@_DELEGATE_TO_CPEV) {
        no strict 'refs';
        *$subname = sub ( $self, @args ) {
            my $cpev = $self->cpev;
            my $sub  = $cpev->can($subname) or die qq[cpev does not support $subname];
            return $sub->( $cpev, @args );
        }
    }
}

1;
