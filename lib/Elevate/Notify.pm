package Elevate::Notify;

=encoding utf-8

=head1 NAME

Elevate::Notify

Helpers to display or send some notifications to the customer during the elevation process.

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

# separate sub, so that it can be silenced during tests:
sub warn_skip_version_check {
    WARN("The --skip-cpanel-version-check option was specified! This option is provided for testing purposes only! cPanel may not be able to support the resulting conversion. Please consider whether this is what you want.");
    return;
}

sub add_final_notification ( $msg, $warn_now = 0 ) {
    my $stage_info = cpev::read_stage_file();

    return unless defined $msg && length $msg;

    cpev::update_stage_file( { final_notifications => [$msg] } );    # stacked to the previously stored

    if ($warn_now) {
        foreach my $l ( split( "\n", $msg ) ) {
            next unless length $l;
            WARN($l);
        }
    }

    return 1;
}
1;
