package Elevate::Components;

=encoding utf-8

=head1 NAME

Elevate::Components

This is providing the entry point and helpers to run
one or more helpers.

You should plug any new blockers in the class.

=cut

use cPstrict;

# enforce packing these packages
use Elevate::Components::Base ();

use Elevate::Components::AbsoluteSymlinks   ();
use Elevate::Components::AutoSSL            ();
use Elevate::Components::BootKernel         ();
use Elevate::Components::CCS                ();
use Elevate::Components::CloudLinux         ();
use Elevate::Components::cPanelPlugins      ();
use Elevate::Components::cPanelPrep         ();
use Elevate::Components::DatabaseUpgrade    ();
use Elevate::Components::DiskSpace          ();
use Elevate::Components::Distros            ();
use Elevate::Components::DNS                ();
use Elevate::Components::EA4                ();
use Elevate::Components::ElevateScript      ();
use Elevate::Components::ELS                ();
use Elevate::Components::Grub2              ();
use Elevate::Components::Imunify            ();
use Elevate::Components::InfluxDB           ();
use Elevate::Components::IsContainer        ();
use Elevate::Components::JetBackup          ();
use Elevate::Components::KernelCare         ();
use Elevate::Components::Kernel             ();
use Elevate::Components::Leapp              ();
use Elevate::Components::LiteSpeed          ();
use Elevate::Components::MountPoints        ();
use Elevate::Components::MySQL              ();
use Elevate::Components::NICs               ();
use Elevate::Components::NixStats           ();
use Elevate::Components::OVH                ();
use Elevate::Components::PackageRestore     ();
use Elevate::Components::Panopta            ();
use Elevate::Components::PECL               ();
use Elevate::Components::PerlXS             ();
use Elevate::Components::PostgreSQL         ();
use Elevate::Components::R1Soft             ();
use Elevate::Components::Repositories       ();
use Elevate::Components::RmMod              ();
use Elevate::Components::RpmDB              ();
use Elevate::Components::SSH                ();
use Elevate::Components::UnconvertedModules ();
use Elevate::Components::WHM                ();
use Elevate::Components::WPToolkit          ();
use Elevate::Components::Acronis            ();

use Simple::Accessor qw(
  cpev
  check_mode
  blockers
  abort_on_first_blocker
);

use Log::Log4perl qw(:easy);
use Cpanel::JSON  ();

# This is where you should add your blockers class
# note: the order matters
our @CHECKS = qw{

  IsContainer
  ElevateScript
  MountPoints
  SSH

  DiskSpace
  WHM
  Distros
  CloudLinux
  Imunify
  DNS

  MySQL
  Repositories
  JetBackup
  NICs
  EA4
  BootKernel
  Grub2
  OVH
  AbsoluteSymlinks
  AutoSSL
};

# This is where to add new components that
# have checks that are noops
our @NOOP_CHECKS = qw{
  CCS
  DatabaseUpgrade
  ELS
  InfluxDB
  Kernel
  KernelCare
  LiteSpeed
  NixStats
  PECL
  PackageRestore
  Panopta
  PerlXS
  PostgreSQL
  R1Soft
  RmMod
  RpmDB
  UnconvertedModules
  WPToolkit
  cPanelPlugins
  cPanelPrep
  Acronis
};

push @CHECKS, @NOOP_CHECKS;

push @CHECKS, 'Leapp';    # This blocker has to run last!

use constant ELEVATE_BLOCKER_FILE => '/var/cpanel/elevate-blockers';

our $_CHECK_MODE;         # for now global so we can use the helper (move it later to the object)

sub _build_blockers { return []; }

sub check ($self) {    # do_check - main  entry point

    if ( $self->cpev->service->is_active ) {
        WARN("An elevation process is already in progress.");
        return 1;
    }

    my $stage = Elevate::Stages::get_stage();
    if ( $stage != 0 && $stage <= cpev::VALID_STAGES() ) {
        die <<~"EOS";
        An elevation process is currently in progress: running stage $stage
        You can check the log by running:
            /scripts/elevate-cpanel --log
        or check the elevation status:
            /scripts/elevate-cpanel --status
        EOS
    }

    Elevate::Components::Distros::bail_out_on_inappropriate_distro();

    # If no argument passed to --check, use default path:
    my $blocker_file = $self->cpev->getopt('check') || ELEVATE_BLOCKER_FILE;

    my $has_blockers = $self->_has_blockers( $self->cpev->getopt('start') ? 0 : 1 );

    $self->save( $blocker_file, { 'blockers' => $self->{'blockers'} } );

    if ($has_blockers) {
        WARN( <<~'EOS' );
        Please fix the detected issues before performing the elevation process.
        Read More: https://cpanel.github.io/elevate/blockers/
        EOS
    }
    else {
        my $cmd = q[/scripts/elevate-cpanel --start];
        INFO( <<~"EOS" );
        There are no known blockers to start the elevation process.
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

    $_CHECK_MODE = !!$check_mode;    # running with --check
    $self->abort_on_first_blocker(0);

    my $ok = eval { $self->_check_all_blockers; 1; };

    if ( !$ok ) {
        my $error = $@;
        if ( ref $error eq 'cpev::Blocker' ) {
            ERROR( $error->{msg} );
            return 401;
        }
        WARN("Unknown error while checking blockers: $error");
        return 127;    # unknown error
    }

    return scalar $self->blockers->@*;
}

sub num_blockers_found ($self) {
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

    foreach my $blocker (@CHECKS) {    # preserve order
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
    my $pkg = "Elevate::Components::$name";    # need to be loaded
    return $pkg->new( components => $self );
}

1;
