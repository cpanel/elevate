package Elevate::Blockers::Leapp;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Leapp

Blocker to check if leapp finds any upgrade inhibitors.

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return if $self->is_check_mode();    # skip for --check

    return unless $self->should_run_leapp;    # skip when --no-leapp is provided

    return if ( $self->blockers->num_blockers_found() > 0 );    # skip if any blockers have already been found

    $self->cpev->leapp->install();

    $self->cpev->leapp->preupgrade();

    my $blockers = $self->cpev->leapp->search_report_file_for_blockers(
        qw(
          check_installed_devel_kernels
          verify_check_results
        )
    );

    foreach my $blocker (@$blockers) {
        my $message = $blocker->{title} . "\n";
        $message .= $blocker->{summary} . "\n";
        if ( $blocker->{hint} ) {
            $message .= "Possible resolution: " . $blocker->{hint} . "\n";
        }
        if ( $blocker->{command} ) {
            $message .= "Consider running:" . "\n" . $blocker->{command} . "\n";
        }

        $self->has_blocker($message);
    }

    return;
}

1;
