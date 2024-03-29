package Elevate::Notify;

=encoding utf-8

=head1 NAME

Elevate::Notify

Helpers to display or send some notifications to the customer during the elevation process.

=cut

use cPstrict;

use Elevate::StageFile ();

use Log::Log4perl qw(:easy);

# separate sub, so that it can be silenced during tests:
sub warn_skip_version_check {
    WARN("The --skip-cpanel-version-check option was specified! This option is provided for testing purposes only! cPanel may not be able to support the resulting conversion. Please consider whether this is what you want.");
    return;
}

sub add_final_notification ( $msg, $warn_now = 0 ) {
    my $stage_info = Elevate::StageFile::read_stage_file();

    return unless defined $msg && length $msg;

    Elevate::StageFile::update_stage_file( { final_notifications => [$msg] } );    # stacked to the previously stored

    if ($warn_now) {
        foreach my $l ( split( "\n", $msg ) ) {
            next unless length $l;
            WARN($l);
        }
    }

    return 1;
}

sub send_notification ( $subject, $msg, %opts ) {

    eval {
        _send_notification( $subject, $msg, %opts );
        1;
    }
      or warn "Failed to send notification: $@";

    return;
}

sub _send_notification ( $subject, $msg, %opts ) {

    my $is_success = delete $opts{is_success};

    # note: no need to use one iContact::Class this is a one shot message
    require Cpanel::iContact;

    INFO("Sending notification: $subject");

    my $log   = $is_success ? \&INFO : \&ERROR;
    my @lines = split( "\n", $msg );
    foreach my $line (@lines) {
        $log->($line);
    }

    Cpanel::iContact::icontact(
        'application' => 'elevate',
        'subject'     => $subject,
        'message'     => $msg,
    );

    return;
}
1;
