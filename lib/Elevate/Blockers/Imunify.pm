package Elevate::Blockers::Imunify;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Imunify

Blocker to check that the Imunify license is valid when Imunify is installed.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();

use Cpanel::JSON ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

sub check ($self) {
    return $self->_check_imunify_license();
}

sub _check_imunify_license ($self) {
    return unless -x Elevate::Constants::IMUNIFY_AGENT;

    my $agent_bin    = Elevate::Constants::IMUNIFY_AGENT;
    my $out          = $self->ssystem_hide_and_capture_output( $agent_bin, 'version', '--json' );
    my $raw_data     = join "\n", @{ $out->{stdout} };
    my $license_data = eval { Cpanel::JSON::Load($raw_data) } // {};

    if ( !ref $license_data->{license} || !$license_data->{license}->{status} ) {

        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
        return $self->has_blocker( <<~"EOS");
        The Imunify license is reporting that it is not currently valid.  Since
        Imunify is installed on this system, a valid Imunify license is required
        to ELevate to $pretty_distro_name.
        EOS
    }

    return;
}

1;
