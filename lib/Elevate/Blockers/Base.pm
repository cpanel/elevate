package Elevate::Blockers::Base;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Base

This is the base package used by all blockers.

=cut

use cPstrict;

use Carp         ();
use Cpanel::JSON ();

use Simple::Accessor qw(
  blockers
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

    my $analytics_data;
    if ( $others{info} ) {
        my $info = delete $others{info};

        if ( ref $info eq 'HASH' ) {
            $analytics_data = Cpanel::JSON::canonical_dump( [$info] );
        }
        else {

            # only die if this is a developement version since we do not analytics data to potentially affect
            # the ability to elevate in production
            my ( $latest_version, $self_version ) = ( $self->cpev->script->latest_version(), cpev::VERSION() );
            if ( $self_version > $latest_version ) {
                die "Invalid data analytics given to blocker.  'info' must be a hash reference.\n";
            }
        }
    }

    my $blocker = cpev::Blocker->new( id => $caller_id, msg => $msg, %others, info => $analytics_data );
    $self->blockers->add_blocker($blocker);
    die $blocker if $self->blockers->abort_on_first_blocker();

    if ( !$others{'quiet'} ) {
        WARN( <<~"EOS");
        *** Elevation Blocker detected: ***
        $msg
        EOS
    }

    return $blocker;
}

# Needed to convert these with Cpanel::JSON::Dump:
{

    package cpev::Blocker;

    use Simple::Accessor qw{ id msg info };

    sub TO_JSON ($self) {
        my %hash = $self->%*;
        return \%hash;
    }
}

1;
