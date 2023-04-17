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

1;
