package Elevate::NICs;

=encoding utf-8

=head1 NAME

Elevate::NICs

Helper/Utility logic for NIC related tasks.

=cut

use cPstrict;

use Elevate::Constants ();

use Cpanel::SafeRun::Errors ();

sub get_nics () {
    my $sbin_ip = Elevate::Constants::SBIN_IP();
    my $ip_info = Cpanel::SafeRun::Errors::saferunnoerror( $sbin_ip, 'addr' ) // '';

    my @eths;
    foreach my $line ( split /\n/xms, $ip_info ) {
        $line =~ /^[0-9]+: \s (eth[0-9]):/xms
          or next;

        my $eth   = $1;
        my $value = readlink "/sys/class/net/$eth"
          or next;

        $value =~ m{/virtual/}xms
          and next;

        push @eths, $eth;
    }

    return @eths;
}

1;
