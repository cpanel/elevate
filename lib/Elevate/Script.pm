package Elevate::Script;

=encoding utf-8

=head1 NAME

Elevate::Script

Object to fetch and check the elevate script.

=cut

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
    my $response = Cpanel::HTTP::Client->new->get( $self->base_url() . 'version' );
    return undef if !$response->success;
    my $version = $response->content // '';
    chomp $version if length $version;
    return $version;
}

sub is_out_of_date ($self) {
    my ( $should_block, $message );

    my ( $latest_version, $self_version ) = ( $self->latest_version(), cpev::VERSION() );

    if ( !defined $latest_version ) {
        $should_block = 1;
        $message      = "The script could not fetch information about the latest version.";
    }
    elsif ( $self_version > $latest_version ) {
        $message = qq[You are using a development version of elevate-cpanel. Latest version available is v$latest_version.];
    }
    elsif ( $self_version < $latest_version ) {
        $should_block = 1;
        $message      = <<~EOS;
        This script (version $self_version) does not appear to be the newest available release ($latest_version).
        Run this script with the --update option:

        /scripts/elevate-cpanel --update
        EOS
    }

    return ( $should_block, $message );
}

sub fetch ($self) {
    return Elevate::Fetch::script( $self->base_url . 'elevate-cpanel', 'elevate-cpanel', '' );
}

1;
