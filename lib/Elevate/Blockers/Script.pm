package Elevate::Blockers::Script;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Script

Blocker to check if the script is run from the correct location.

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return $self->_blocker_wrong_location;
}

sub _blocker_wrong_location ($self) {

    # ensure the script is installed at the correct location
    my $running_from = Cwd::abs_path($0) // '';

    unless ( $running_from eq '/usr/local/cpanel/scripts/elevate-cpanel' ) {
        return $self->has_blocker( <<~'EOS');
        The script is not installed to the correct directory.
        Please install it to /scripts/elevate-cpanel and run it again.
        EOS
    }

    return 0;
}

1;
