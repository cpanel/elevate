package Elevate::Components::NICs;

=encoding utf-8

=head1 NAME

Elevate::Components::NICs

=head2 check

Determine if the server has multiple NIC devices using the kernel (ethX)
namespace

=head2 pre_distro_upgrade

Rename NICs using the kernel (ethX) namespace

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use File::Slurper ();

use Elevate::Constants ();
use Elevate::NICs      ();
use Elevate::OS        ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant ETH_FILE_PREFIX           => Elevate::Constants::ETH_FILE_PREFIX;
use constant NIC_PREFIX                => q[cp];
use constant PERSISTENT_NET_RULES_PATH => q[/etc/udev/rules.d/70-persistent-net.rules];
use constant SBIN_IP                   => Elevate::Constants::SBIN_IP;

sub pre_distro_upgrade ($self) {

    $self->_rename_nics();

    return;
}

sub _rename_nics ($self) {

    # Only do this if there are multiple NICs in the kernel (eth) namespace
    my @nics = Elevate::NICs::get_nics();
    return unless scalar @nics > 1;

    foreach my $nic (@nics) {
        my $nic_path = ETH_FILE_PREFIX . $nic;

        my $die_msg = <<~"EOS";
        The file for the network interface card (NIC) using kernel-name ($nic) does
        not exist at the expected location ($nic_path).  We are unable to
        change the name of this NIC due to this.  You will need to resolve this
        issue manually before elevate can continue.  Once the issue has been
        resolved, you can continue this script by executing:

        /scripts/elevate-cpanel --continue
        EOS
        die "$die_msg\n" unless -s $nic_path;

        my $new_nic = NIC_PREFIX . $nic;
        INFO("Renaming $nic to $new_nic");

        # Update the name of the NIC in the network config file
        my $device_line_found = 0;
        my $txt               = File::Slurper::read_binary($nic_path);
        my @nic_lines         = split( "\n", $txt );
        foreach my $line (@nic_lines) {
            if ( $line =~ m{^\s*DEVICE\s*=\s*\Q$nic\E\s*$} ) {
                $device_line_found = 1;
                $line              = "DEVICE=$new_nic";
                last;
            }
        }
        die qq[Unable to rename $nic to $new_nic.  The line beginning with 'DEVICE' in $nic_path was not found.\n] unless $device_line_found;

        my $new_nic_path = ETH_FILE_PREFIX . $new_nic;
        File::Slurper::write_binary( $new_nic_path, join( "\n", @nic_lines ) );

        unlink $nic_path;

        # If this file exists, then it will be read on reboot and the network
        # config files will be expected to match.  Most virtual servers will
        # have this file and networking will not come back up on reboot if the
        # values in this file do not match the values in the network config files
        next unless -s PERSISTENT_NET_RULES_PATH;
        my $rules_txt   = File::Slurper::read_binary( PERSISTENT_NET_RULES_PATH() );
        my @rules_lines = split( "\n", $rules_txt );
        foreach my $line (@rules_lines) {
            $line =~ s/NAME="\Q$nic\E"/NAME="$new_nic"/;
        }

        my $new_rules_txt = join( "\n", @rules_lines );
        $new_rules_txt .= "\n";
        File::Slurper::write_binary( PERSISTENT_NET_RULES_PATH(), $new_rules_txt );
    }

    return;
}

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

        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
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
