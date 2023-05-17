package Elevate::Blockers::AbsoluteSymlinks;

=encoding utf-8

=head1 NAME

Elevate::Blockers::AbsoluteSymlinks

Blocker code to *warn* about absolute paths on symlinks in /, as we will be
correcting these before run.

=cut

use cPstrict;

use Elevate::Components::AbsoluteSymlinks ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Blockers::Base};

sub check ($self) {
    my %links = Elevate::Components::AbsoluteSymlinks::get_abs_symlinks();
    WARN("Symlinks with absolute paths have been found in /:\n\t"
        . join( ", ", sort keys(%links) ) . "\n"
        ."This can cause problems during the leapp run, so\n"
        .'these will be corrected to be relative symlinks before elevation.'
    ) if %links;
    return;
}

1;
