package Elevate::Blockers::ElevateScript;

=encoding utf-8

=head1 NAME

Elevate::Blockers::ElevateScript

Blocker to check if the script is run from the correct location
and is up to date

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    $self->_blocker_wrong_location;
    $self->_is_up_to_date;

    return;
}

sub _blocker_wrong_location ($self) {

    # ensure the script is installed at the correct location
    my $running_from = Cwd::abs_path($0) // '';

    # right location
    return 0
      if $running_from eq '/scripts/elevate-cpanel'
      || $running_from eq '/usr/local/cpanel/scripts/elevate-cpanel';

    return $self->has_blocker( <<~'EOS');
        The script is not installed to the correct directory.
        Please install it to /scripts/elevate-cpanel and run it again.
        EOS

}

sub _is_up_to_date ($self) {    # $self is a cpev object here

    return if $self->getopt('skip-elevate-version-check');

    my ( $should_block, $message ) = $self->cpev->script->is_out_of_date();
    $message //= '';

    if ( !$should_block ) {
        WARN($message) if length $message;
        return;
    }

    return $self->has_blocker( <<~"EOS");
    $message

    Pass the --skip-elevate-version-check flag to skip this check.
    EOS
}

1;
