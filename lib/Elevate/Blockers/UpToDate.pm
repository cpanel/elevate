package Elevate::Blockers::UpToDate;

use cPstrict;

use Elevate::Constants ();
use Elevate::Fetch     ();

sub check ($self) {    # $self is a cpev object here

    return if $self->getopt('skip-elevate-version-check');

    my ( $should_block, $blocker_text ) = $self->script->is_out_of_date();

    return unless $should_block;

    return $self->has_blocker( 105, $blocker_text . <<~EOS);


    Pass the --skip-elevate-version-check flag to skip this check.
    EOS
}

1;
