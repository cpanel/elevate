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

    return $self->_blocker_nameserver_not_supported( _get_nameserver_type() );
}

sub _get_nameserver_type () {

    my $cpconf = Cpanel::Config::LoadCpConf::loadcpconf();
    return $cpconf->{'local_nameserver_type'} // '';
}

sub _blocker_nameserver_not_supported ( $self, $nameserver = '' ) {

    # Nameserver is not set so it is likely disabled which is ok
    return 0 unless length $nameserver;

    my @supported_nameserver_types = Elevate::OS::supported_cpanel_nameserver_types();
    return 0 if grep { $_ eq $nameserver } @supported_nameserver_types;

    my $pretty_distro_name    = Elevate::OS::upgrade_to_pretty_name();
    my $supported_nameservers = join( "\n", @supported_nameserver_types );
    return $self->has_blocker( <<~"EOS");
    $pretty_distro_name only supports the following nameservers:

    $supported_nameservers

    We suggest you switch to powerdns.
    Before upgrading, we suggest you run:

    /usr/local/cpanel/scripts/setupnameserver powerdns

    EOS
}

1;
