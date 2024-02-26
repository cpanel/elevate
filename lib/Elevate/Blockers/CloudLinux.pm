package Elevate::Blockers::CloudLinux;

=encoding utf-8

=head1 NAME

Elevate::Blockers::CloudLinux

Blocker to check that the CloudLinux licese is valid for CloudLinux upgrades only.

=cut

use cPstrict;

use parent qw{Elevate::Blockers::Base};

use Elevate::OS ();

use Log::Log4perl qw(:easy);

use constant CLDETECT  => '/usr/bin/cldetect';
use constant RHN_CHECK => '/usr/sbin/rhn_check';

sub check ($self) {
    return $self->_check_cloudlinux_license();
}

sub _check_cloudlinux_license ($self) {
    return 0 unless Elevate::OS::should_check_cloudlinux_license();

    my $out = $self->ssystem_capture_output( CLDETECT, '--check-license' );

    if ( $self->ssystem(RHN_CHECK) != 0 || $out->{status} != 0 || grep { $_ !~ m/^ok/i } @{ $out->{stdout} } ) {

        $self->blockers->abort_on_first_blocker(1);

        return $self->has_blocker( <<~'EOS');
        The CloudLinux license is reporting that it is not currently valid.  A
        valid CloudLinux license is required to ELevate from CloudLinux 7 to
        CloudLinux 8.
        EOS
    }

    return 0;
}

1;
