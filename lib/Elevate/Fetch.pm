package Elevate::Fetch;

=encoding utf-8

=head1 NAME

Elevate::Fetch

Helper to fetch a script to a temporary location.

=cut

use cPstrict;

use Elevate::Constants   ();
use Cpanel::HTTP::Client ();
use File::Temp           ();

use Log::Log4perl qw(:easy);

sub script ( $url, $template, $suffix = '.sh' ) {
    my $response = eval {
        my $http = Cpanel::HTTP::Client->new()->die_on_http_error();
        $http->get($url);
    };

    if ( my $exception = $@ ) {
        ERROR("The system could not fetch the script for $template: $exception");
        return;
    }

    my $fh = File::Temp->new(
        TEMPLATE => "${template}_XXXX",
        SUFFIX   => $suffix,
        UNLINK   => 0,
        PERMS    => 0600,
        TMPDIR   => 1
      )
      or do {
        ERROR(qq[Cannot create a temporary file]);
        return;
      };
    print {$fh} $response->{'content'};
    close $fh;

    return "$fh";
}

1;
