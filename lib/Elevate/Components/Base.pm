package Elevate::Components::Base;

=encoding utf-8

=head1 NAME

Elevate::Components::Base

This is the base class to any components used by the elevate script.

A component allows to group together some actions which need to be performed
before / after the elevation process as well as perform some checks that determine that the server is eligible to perform the elevation process on.

=cut

use cPstrict;

use Carp ();

use Cpanel::JSON ();

use Simple::Accessor qw(
  components
);

use Log::Log4perl qw(:easy);

# delegate to cpev
BEGIN {
    my @_DELEGATE_TO_CPEV = qw{
      getopt
      upgrade_distro_manually
      ssystem
      ssystem_and_die
      ssystem_capture_output
      ssystem_hide_and_capture_output
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

sub _build_components {
    if ( $0 =~ qr{\bt/} ) {

        # only for testing
        return Elevate::Components->new;
    }

    # outside unit tests we should always be initialized with an 'Elevate::Components' object
    Carp::confess(q[Missing components]);
}

sub cpev ($self) {
    return $self->components->cpev;
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

=head2 $self->is_check_mode( @args )

Check if the script is called using '--check'

delegate to blockers

=cut

sub is_check_mode ( $self, @args ) {
    return $self->components->is_check_mode(@args);
}

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
    $self->components->add_blocker($blocker);
    die $blocker if $self->components->abort_on_first_blocker();

    if ( !$others{'quiet'} ) {
        ERROR(<<~"EOS");
        *** Elevation Blocker detected: ***
        $msg
        EOS
    }

    return $blocker;
}

sub check ($self) {
    return;
}

sub pre_distro_upgrade ($self) {
    return;
}

sub post_distro_upgrade ($self) {
    return;
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
