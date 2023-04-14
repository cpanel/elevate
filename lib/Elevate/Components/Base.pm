package Elevate::Components::Base;

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
