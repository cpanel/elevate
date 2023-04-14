package Elevate::Blockers::NICs;

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

use constant SBIN_IP => q[/sbin/ip];

sub check ($self) {
    return $self->_blocker_bad_nics_naming;
}

sub _blocker_bad_nics_naming ($self) {
    return $self->has_blocker( q[Missing ] . SBIN_IP . ' binary' ) unless -x SBIN_IP;
    my @eths = _get_nics();
    if ( @eths >= 2 ) {
        return $self->has_blocker( <<~'EOS');
        Your machine has multiple network interface cards (NICs) using kernel-names (ethX).
        Since the upgrade process cannot guarantee their stability after upgrade, you cannot upgrade.

        Please provide those interfaces new names before continuing the update.
        EOS
    }

    return 0;
}

sub _get_nics {
    my $ip_info = Cpanel::SafeRun::Errors::saferunnoerror( SBIN_IP, 'addr' ) // '';

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
