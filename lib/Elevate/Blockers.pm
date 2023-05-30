package Elevate::Blockers;

=encoding utf-8

=head1 NAME

Elevate::Blockers

This is providing the entry point and helpers to run
one or more helpers.

You should plug any new blockers in the class.

=cut

use cPstrict;

# enforce packing these packages
use Elevate::Blockers::Base ();

use Elevate::Blockers::AbsoluteSymlinks ();
use Elevate::Blockers::Databases        ();
use Elevate::Blockers::DiskSpace        ();
use Elevate::Blockers::Distros          ();
use Elevate::Blockers::DNS              ();
use Elevate::Blockers::EA4              ();
use Elevate::Blockers::Grub2            ();
use Elevate::Blockers::IsContainer      ();
use Elevate::Blockers::JetBackup        ();
use Elevate::Blockers::NICs             ();
use Elevate::Blockers::OVH              ();
use Elevate::Blockers::Python           ();
use Elevate::Blockers::ElevateScript    ();
use Elevate::Blockers::SSH              ();
use Elevate::Blockers::WHM              ();
use Elevate::Blockers::Repositories     ();

use Simple::Accessor qw(
  cpev
  check_mode
  blockers
);

use Log::Log4perl qw(:easy);
use Cpanel::JSON  ();

# This is where you should add your blockers class
# note: the order matters
our @BLOCKERS = qw{

  IsContainer
  ElevateScript

  DiskSpace
  WHM
  Distros
  DNS

  Databases
  Repositories
  SSH
  JetBackup
  NICs
  EA4
  BootKernel
  Grub2
  OVH
  Python
  AbsoluteSymlinks
};

use constant ELEVATE_BLOCKER_FILE => '/var/cpanel/elevate-blockers';

our $_CHECK_MODE;    # for now global so we can use the helper (move it later to the object)

sub _build_blockers { [] }

sub check ($self, %opts) {    # do_check - main  entry point

    if ( $self->cpev->service->is_active ) {
        WARN("An elevation process is already in progress.");
        return 1;
    }

    Elevate::Blockers::Distros::bail_out_on_inappropriate_distro();

    # If no argument passed to --check, use default path:
    my $blocker_file = $self->cpev->getopt('check') || ELEVATE_BLOCKER_FILE;

    my $has_blockers = $self->_has_blockers($opts{'dry_run'});

    $self->save( $blocker_file, { 'blockers' => $self->{'blockers'} } );

    if ($has_blockers) {
        WARN( <<~'EOS' );
        Please fix the detected issues before performing the elevation process.
        Read More: https://cpanel.github.io/elevate/blockers/
        EOS
    }
    else {
        my $cmd = q[/scripts/elevate-cpanel --start];
        if ( my $flavor = $self->cpev->getopt('upgrade-to') ) {
            $cmd = "$cmd --upgrade-to=$flavor";
        }
        INFO( <<~"EOS" );
        There is no known blockers to start the elevation process.
        You can consider running:
            $cmd
        EOS
    }

    return $has_blockers;
}

sub _has_blockers ( $self, $check_mode = 0 ) {

    unless ( $< == 0 ) {
        ERROR("This script can only be run by root");
        return 666;
    }

    $_CHECK_MODE = !!$check_mode;                              # running with --check
    $self->cpev->{_abort_on_first_blocker} = !$_CHECK_MODE;    # abort on first blocker

    my $ok = eval { $self->_check_all_blockers; 1; };

    if ( !$ok ) {
        my $error = $@;
        if ( ref $error eq 'cpev::Blocker' ) {
            ERROR( $error->{msg} );
            return $error->{id} // 401;
        }
        WARN("Unknown error while checking blockers: $error");
        return 127;    # unknown error
    }

    return scalar $self->blockers->@*;
}

sub add_blocker ( $self, $blocker ) {
    push $self->blockers->@*, $blocker;
    return;
}

sub is_check_mode ($) {
    return $_CHECK_MODE;
}

sub save ( $self, $path, $stash ) {

    open( my $fh, '>', $path ) or LOGDIE( "Failed to open " . $path . ": $!" );

    print {$fh} Cpanel::JSON::pretty_canonical_dump($stash);
    close $fh;

    return 1;
}

sub _check_all_blockers ($self) {    # sub _blockers_check ($self) {

    foreach my $blocker (@BLOCKERS) {    # preserve order
        $self->_check_single_blocker($blocker);
    }

    return 0;
}

sub _check_single_blocker ( $self, $name ) {
    my $blocker = $self->_get_blocker_for($name);

    my $check = $blocker->can('check')
      or die qq[Missing check function from ] . ref($blocker);

    return $check->($blocker);
}

sub _get_blocker_for ( $self, $name ) {    # useful for tests
    my $pkg = "Elevate::Blockers::$name";    # need to be loaded
    return $pkg->new( blockers => $self );
}

1;
