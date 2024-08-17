package Elevate::Blockers::KernelCare;

=encoding utf-8

=head1 NAME

Elevate::Blockers::KernelCare

Blocker to check if KernelCare is supported for the upgrade if it is installed.

=cut

use cPstrict;

use parent qw{Elevate::Blockers::Base};

use Elevate::OS ();

use Log::Log4perl qw(:easy);

sub check ($self) {
    return unless -x q[/usr/bin/kcarectl];
    return if Elevate::OS::supports_kernelcare();

    my $name = Elevate::OS::default_upgrade_to();
    return $self->has_blocker( <<~"EOS" );
    ELevate does not currently support KernelCare for upgrades of $name.
    Support for KernelCare on $name will be added in a future version of ELevate.
    EOS
}

1;
