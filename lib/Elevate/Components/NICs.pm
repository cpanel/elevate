package Elevate::Components::NICs;

=encoding utf-8

=head1 NAME

Elevate::Components::NICs

Rename NICs in the kernel namespace from ethX to cpethX

=cut

use cPstrict;

use File::Slurper ();

use Elevate::Constants ();
use Elevate::NICs      ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant ETH_FILE_PREFIX           => Elevate::Constants::ETH_FILE_PREFIX;
use constant NIC_PREFIX                => q[cp];
use constant PERSISTENT_NET_RULES_PATH => q[/etc/udev/rules.d/70-persistent-net.rules];

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

sub post_distro_upgrade ($self) {
    return;
}

1;
