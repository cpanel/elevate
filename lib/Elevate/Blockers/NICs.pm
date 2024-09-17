package Elevate::Blockers::NICs;

=encoding utf-8

=head1 NAME

Elevate::Blockers::NICs

Blocker to check if the server is using multiple NICs.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::NICs      ();

use parent qw{Elevate::Blockers::Base};

use Log::Log4perl qw(:easy);

use constant ETH_FILE_PREFIX => Elevate::Constants::ETH_FILE_PREFIX;
use constant SBIN_IP         => Elevate::Constants::SBIN_IP;

sub check ($self) {
    return 1 unless $self->should_run_distro_upgrade;    # skip when --upgrade-distro-manually is provided
    return $self->_blocker_bad_nics_naming;
}

sub _blocker_bad_nics_naming ($self) {
    return $self->has_blocker( q[Missing ] . SBIN_IP . ' binary' ) unless -x SBIN_IP;
    my @eths = Elevate::NICs::get_nics();
    if ( @eths >= 2 ) {
        WARN( <<~'EOS' );
        Your machine has multiple network interface cards (NICs) using
        kernel-names (ethX).
        EOS

        if ( $self->is_check_mode() ) {
            INFO( <<~'EOS' );
            Since the upgrade process cannot guarantee their stability after
            upgrade, we will need to rename these interfaces before upgrading.
            EOS
            return 0;
        }

        return if $self->_nics_have_missing_ifcfg_files(@eths);

        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        WARN( <<~"EOS" );
        Prior to elevating this system to $pretty_distro_name, we will
        automatically rename these interfaces.

        EOS

        if ( !$self->getopt('non-interactive') ) {
            if (
                !IO::Prompt::prompt(
                    '-one_char',
                    '-yes_no',
                    '-tty',
                    -default => 'y',
                    'Do you consent to renaming your NICs to use non kernel-names [Y/n]: ',
                )
            ) {
                return $self->has_blocker( <<~"EOS" );
                The system cannot be elevated to $pretty_distro_name until the
                NICs using kernel-names (ethX) have been updated with new names.

                Please provide those interfaces new names before continuing the
                update.

                To have this script perform the upgrade, run this script again
                and consent to allow it to rename the NICs.
                EOS
            }
        }
    }

    return 0;
}

sub _nics_have_missing_ifcfg_files ( $self, @nics ) {

    my @nics_missing_nic_path;
    foreach my $nic (@nics) {
        my $nic_path = ETH_FILE_PREFIX . $nic;

        my $err_msg = <<~"EOS";
        The file for the network interface card (NIC) using kernel-name ($nic) does
        not exist at the expected location ($nic_path).  We are unable to
        change the name of this NIC due to this.  You will need to resolve this
        issue manually before elevate can continue.

        EOS

        unless ( -s $nic_path ) {
            ERROR($err_msg);
            push @nics_missing_nic_path, $nic;
        }
    }

    if (@nics_missing_nic_path) {
        my $missing_nics = join "\n", @nics_missing_nic_path;
        return $self->has_blocker( <<~"EOS" );
        This script is unable to rename the following network interface cards
        due to a missing ifcfg file:

        $missing_nics

        Please provide these interfaces new names before continuing the update.
        EOS
    }

    return;
}

1;
