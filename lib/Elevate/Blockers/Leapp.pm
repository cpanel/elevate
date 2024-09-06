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

    return unless $self->should_run_distro_upgrade;    # skip when --upgrade-distro-manually is provided

    return if ( $self->blockers->num_blockers_found() > 0 );    # skip if any blockers have already been found

    $self->cpev->leapp->install();

    my $out = $self->cpev->leapp->preupgrade();

    # A return code of zero indicates that no inhibitors
    # or fatal errors have been found. I.e., success.
    return if ( $out->{status} == 0 );

    $self->_check_for_inhibitors();

    $self->_check_for_fatal_errors($out);

    if ( $self->blockers->num_blockers_found() > 0 ) {
        INFO('Leapp found issues which would prevent the upgrade, more information can be obtained in the files under /var/log/leapp');
    }

    return;
}

sub _check_for_inhibitors ($self) {

    # Leapp will generate a JSON report file which contains any
    # inhibitors found. Find any reported inhibitors but exclude ones
    # that we know about and will fix before the upgrade.
    # (Inhibitors will also be reported in stdout in a block
    # labeled "UPGRADE INHIBITORS"; but more complete info is reported
    # in the JSON report file.)

    my $inhibitors = $self->cpev->leapp->search_report_file_for_inhibitors(
        qw(
          check_detected_devices_and_drivers
          check_installed_devel_kernels
          cl_mysql_repository_setup
          persistentnetnamesdisable
          verify_check_results
        )
    );

    foreach my $inhibitor (@$inhibitors) {
        my $message = $inhibitor->{title} . "\n";
        $message .= $inhibitor->{summary} . "\n";
        if ( $inhibitor->{hint} ) {
            $message .= "Possible resolution: " . $inhibitor->{hint} . "\n";
        }
        if ( $inhibitor->{command} ) {
            $message .= "Consider running:" . "\n" . $inhibitor->{command} . "\n";
        }

        $self->has_blocker($message);
    }

    return;
}

sub _check_for_fatal_errors ( $self, $out ) {

    # Fatal errors will NOT be flagged as inhibitors in the
    # leapp reports.  So it is NOT possible to distinguish them from
    # any non-fatal conditions reported there.  So, we need to fish
    # them from stdout.

    my $error_block = $self->cpev->leapp->extract_error_block_from_output( $out->{stdout} );

    if ( length $error_block ) {
        $self->has_blocker( "Leapp encountered the following error(s):\n" . $error_block );
    }

    return;
}

1;
