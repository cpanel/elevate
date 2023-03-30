package Elevate::Script;

use cPstrict;

use Elevate::Constants ();
use Elevate::Fetch     ();

use Cpanel::HTTP::Client ();

use Log::Log4perl qw(:easy);

use Simple::Accessor qw{
  latest_version
  base_url
};

use constant DEFAULT_ELEVATE_BASE_URL => 'https://raw.githubusercontent.com/cpanel/elevate/release/';

sub _build_base_url ($self) {
    return $ENV{'ELEVATE_BASE_URL'} || DEFAULT_ELEVATE_BASE_URL;
}

sub _build_latest_version ($self) {
    use Test::More;
    note "running: _build_latest_version";
    my $response = Cpanel::HTTP::Client->new->get( $self->base_url() . 'version' );
    return undef if !$response->success;
    my $version = $response->content // '';
    chomp $version if length $version;
    return $version;
}

sub is_out_of_date ($self) {
    my ( $should_block, $blocker_text ) = ( 0, undef );

    my ( $latest_version, $self_version ) = ( $self->latest_version(), cpev::VERSION() );

    if ( !defined $latest_version ) {
        $should_block = 1;
        $blocker_text = "The script could not fetch information about the latest version.";
    }
    else {
        $should_block = $latest_version == $self_version ? 0 : 1;
        $blocker_text = <<~EOS if $should_block;
            This script (version $self_version) does not appear to be the newest available release ($latest_version).
            Run this script with the --update option:

            /scripts/elevate-cpanel --update
            EOS
    }

    return ( $should_block, $blocker_text );
}

sub fetch ($self) {
    return Elevate::Fetch::script( $self->base_url . 'elevate-cpanel', 'elevate-cpanel', '' );
}

1;
