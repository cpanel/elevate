package Elevate::Blockers::Base;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Base

This is the base package used by all blockers.

=cut

use cPstrict;

use Carp ();

use Simple::Accessor qw(
  blockers
  cpconf
);

use Log::Log4perl qw(:easy);

sub _build_blockers {
    if ( $0 =~ qr{\bt/} ) {

        # only for testing
        return Elevate::Blockers->new;
    }

    # outside unit tests we should always be initialized with an 'Elevate::Blockers' object
    Carp::confess(q[Missing blockers]);
}

sub cpev ($self) {
    return $self->blockers->cpev;
}

# delegate to cpev
BEGIN {
    my @_DELEGATE_TO_CPEV = qw{
      getopt
      update_stage_file
      upgrade_to_rocky
      upgrade_to_pretty_name
      should_run_leapp
      ssystem
      ssystem_capture_output
    };

    foreach my $subname (@_DELEGATE_TO_CPEV) {
        no strict 'refs';
        *$subname = sub ( $self, @args ) {
            my $cpev = $self->cpev          or Carp::confess(qq[Cannot find cpev object to call function $subname]);
            my $sub  = $cpev->can($subname) or Carp::confess(qq[cpev does not support $subname]);
            return $sub->( $cpev, @args );
        }
    }
}

sub _build_cpconf ($self) {
    return Cpanel::Config::LoadCpConf::loadcpconf() // {};
}

=head2 $self->is_check_mode( @args )

Check if the script is called using '--check'

delegate to blockers

=cut

sub is_check_mode ( $self, @args ) {
    return $self->blockers->is_check_mode(@args);
}

#
# by default abort on the first failure,
#   except in check mode where we want all failures
#
sub has_blocker ( $self, $msg, %others ) {

    my $caller_id;
    if ( $others{'blocker_id'} ) {
        $caller_id = $others{'blocker_id'};
    }
    else {
        # get the function caller or the object type as id (used by tests)
        ( undef, undef, undef, $caller_id ) = caller(1);
        $caller_id ||= ref $self;
    }

    my $blocker = cpev::Blocker->new( id => $caller_id, msg => $msg, %others );
    die $blocker if $self->cpev->_abort_on_first_blocker;

    if ( !$others{'quiet'} ) {
        WARN( <<~"EOS");
        *** Elevation Blocker detected: ***
        $msg
        EOS
    }

    $self->blockers->add_blocker($blocker);

    return $blocker;
}

# Needed to convert these with Cpanel::JSON::Dump:
{

    package cpev::Blocker;

    use Simple::Accessor qw{ id msg };

    sub TO_JSON ($self) {
        my %hash = $self->%*;
        return \%hash;
    }
}

1;
