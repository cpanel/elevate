package Elevate::Stages;

=encoding utf-8

=head1 NAME

Elevate::Stages

Library to handle the various stages of the elevate process.

1.  This contains the run stage logic
2.  This contains the logic to determine get/set the stage we are in

=cut

use cPstrict;

sub bump_stage ( $by = 1 ) {

    return Elevate::Stages::update_stage_number( Elevate::Stages::get_stage() + $by );
}

sub get_stage {
    return Elevate::StageFile::read_stage_file( 'stage_number', 0 );
}

sub update_stage_number ($stage_id) {

    if ( $stage_id > 10 ) {    # protection for stage
        require Carp;
        Carp::confess("Invalid stage number $stage_id");
    }

    Elevate::StageFile::update_stage_file( { stage_number => $stage_id } );

    return $stage_id;
}

1;
