package Elevate::Components::DNS;

=encoding utf-8

=head1 NAME

Elevate::Components::DNS

=head2 check

Verify that the DNS server is supported

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();

use parent qw{Elevate::Components::Base};

use Cpanel::Config::LoadCpConf ();

use Cwd           ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return $self->_blocker_non_bind_powerdns( _get_nameserver_type() );
}

sub _get_nameserver_type () {

    my $cpconf = Cpanel::Config::LoadCpConf::loadcpconf();
    return $cpconf->{'local_nameserver_type'} // '';
}

sub _blocker_non_bind_powerdns ( $self, $nameserver = '' ) {

    if ( $nameserver eq 'nsd' or $nameserver eq 'mydns' ) {
        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
        return $self->has_blocker( <<~"EOS");
        $pretty_distro_name only supports bind or powerdns. We suggest you switch to powerdns.
        Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
        EOS
    }

    return 0;
}

1;
