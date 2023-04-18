package Elevate::Blockers::DNS;

=encoding utf-8

=head1 NAME

Elevate::Blockers::DNS

Blocker to check if the DNS server is supported.

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return $self->_blocker_non_bind_powerdns;
}

sub _blocker_non_bind_powerdns ( $self, $nameserver = '' ) {

    if ( $nameserver eq 'nsd' or $nameserver eq 'mydns' ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        return $self->has_blocker( <<~"EOS");
        $pretty_distro_name only supports bind or powerdns. We suggest you switch to powerdns.
        Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
        EOS
    }

    return 0;
}

1;
