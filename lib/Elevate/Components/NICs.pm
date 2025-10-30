package Elevate::Components::NICs;

=encoding utf-8

=head1 NAME

Elevate::Components::NICs

=head2 check

Determine if the ifcfg-* files have the TYPE key present and block if it
is missing for A8->A9 conversions

Determine if the server has multiple NIC devices using the kernel (ethX)
namespace

Determine if there are any ifcfg-* files in place for A9->A10 conversions since
network-scripts is no longer supported and servers must fully upgrade to
NetworkManager as of A10

=head2 pre_distro_upgrade

Rename NICs using the kernel (ethX) namespace

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use File::Slurper ();

use Elevate::Constants ();
use Elevate::OS        ();

use Cpanel::SafeRun::Errors ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

use constant ETH_FILE_PREFIX           => Elevate::Constants::ETH_FILE_PREFIX;
use constant NIC_PREFIX                => q[cp];
use constant PERSISTENT_NET_RULES_PATH => q[/etc/udev/rules.d/70-persistent-net.rules];
use constant SBIN_IP                   => Elevate::Constants::SBIN_IP;

sub check ($self) {

    # This only matters for upgrades performed with the leapp utility
    return 1 unless Elevate::OS::needs_leapp();
    return 1 if $self->upgrade_distro_manually;

    return if $self->_blocker_missing_sbin_ip();
    return if $self->_nics_have_missing_ifcfg_files();

    $self->_blocker_ifcfg_files_missing_type_parameter();
    $self->_blocker_bad_nics_naming();
    $self->_blocker_has_ifcfg_files();
    return;
}

sub pre_distro_upgrade ($self) {
    return unless Elevate::OS::needs_leapp();

    $self->_rename_eth_devices();

    return;
}

sub _blocker_missing_sbin_ip ($self) {
    return $self->has_blocker( q[Missing ] . SBIN_IP . ' binary' ) unless -x SBIN_IP;
    return;
}

sub _rename_eth_devices ($self) {

    # Only do this if there are multiple NICs in the kernel (eth) namespace
    my @nics = $self->get_eths();
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

sub _blocker_ifcfg_files_missing_type_parameter ($self) {
    return unless Elevate::OS::needs_type_in_ifcfg();

    my @bad_ifcfg_files;
    my @nics = $self->get_nics();
    foreach my $nic (@nics) {
        my $nic_path = ETH_FILE_PREFIX . $nic;

        my $found = 0;
        my $txt   = File::Slurper::read_binary($nic_path);
        my @lines = split "\n", $txt;
        foreach my $line (@lines) {
            if ( $line =~ m/^\s*TYPE\s*=/ ) {
                $found = 1;
                last;
            }
        }

        push @bad_ifcfg_files, $nic_path unless $found;
    }

    if (@bad_ifcfg_files) {
        my $ifcfg_files = join "\n", @bad_ifcfg_files;
        return $self->has_blocker(<<~"EOS");
        The following network-scripts files are missing the TYPE key:

        $ifcfg_files

        Since we will be converting from using network-scripts to using NetworkManager
        as part of the OS distro upgrade, the TYPE key needs to be explicitly defined
        within each ifcfg-* file.

        You may want to consider reaching out to cPanel Support for assistance:

        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS
    }

    return;
}

sub _blocker_bad_nics_naming ($self) {
    return unless Elevate::OS::network_scripts_are_supported();

    my @eths = $self->get_eths();
    if ( @eths >= 2 ) {
        WARN(<<~'EOS');
        Your machine has multiple network interface cards (NICs) using
        kernel-names (ethX).
        EOS

        if ( $self->is_check_mode() ) {
            INFO(<<~'EOS');
            Since the upgrade process cannot guarantee their stability after
            upgrade, we will need to rename these interfaces before upgrading.
            EOS
            return 0;
        }

        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
        WARN(<<~"EOS");
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
                return $self->has_blocker(<<~"EOS");
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

sub _nics_have_missing_ifcfg_files ($self) {
    return unless Elevate::OS::network_scripts_are_supported();

    my @nics_missing_nic_path;
    my @nics = $self->get_nics();
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
        return $self->has_blocker(<<~"EOS");
        This script is unable to rename the following network interface cards
        due to a missing ifcfg file:

        $missing_nics

        Please provide these interfaces new names before continuing the update.
        EOS
    }

    return;
}

sub get_eths ($self) {
    my @nics = $self->get_nics();
    my @eths = grep { $_ =~ m/^eth[0-9]+$/ } @nics;
    return @eths;
}

sub get_nics ($self) {
    my $ip_info = Cpanel::SafeRun::Errors::saferunnoerror( SBIN_IP, 'addr' ) // '';

    my @nics;
    foreach my $line ( split /\n/xms, $ip_info ) {

        # For example:
        # 2: ens3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
        # 2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
        next unless $line =~ m/^[0-9]+:\s([a-zA-Z0-9_-]+):/;

        my $nic   = $1;
        my $value = readlink "/sys/class/net/$nic";

        next unless $value;
        next if $value =~ m{/virtual/};

        push @nics, $nic;
    }

    return @nics;
}

sub _blocker_has_ifcfg_files ($self) {
    return if Elevate::OS::network_scripts_are_supported();

    my $glob_path   = ETH_FILE_PREFIX() . '*';
    my @ifcfg_files = grep { $_ !~ m{/ifcfg-lo$} } glob $glob_path;

    return unless @ifcfg_files;

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    WARN(<<~'EOS');
    Your machine has network interface cards configured using the legacy
    network-scripts style configuration.
    EOS

    # This type of configuration is not supported by NetworkManager, so we have
    # no choice but to block if we find this type of file
    my @secondary_ifcfg_files = grep { $_ =~ m/:[0-9]+$/ } @ifcfg_files;
    if (@secondary_ifcfg_files) {
        my $alias_interfaces = join( "\n", @secondary_ifcfg_files );
        return $self->has_blocker(<<~"EOS");
        Additionally, this machine has the following alias interfaces defined within the
        legacy network-scripts configuration:

        $alias_interfaces

        This type of configuration is no longer supported and will be ignored by NetworkManager.
        As such, you will need to manually convert this configuration to be compatible with
        NetworkManager before elevating this server.
        EOS
    }

    if ( $self->is_check_mode() ) {
        INFO(<<~"EOS");
        Starting with $pretty_distro_name, the legacy network-scripts style configuration
        is no longer supported.  This script will need to convert these configuration
        files to the NetworkManager style configuration before upgrading.
        EOS

        return;
    }

    WARN(<<~"EOS");
    Prior to elevating this system to $pretty_distro_name, this script will automatically
    convert the legacy network-scripts style configuration to the NetworkManager style
    configuration.

    EOS

    if ( !$self->getopt('non-interactive') ) {
        if (
            !IO::Prompt::prompt(
                '-one_char',
                '-yes_no',
                '-tty',
                -default => 'y',
                'Do you consent to converting your network configuration from network-scripts to NetworkManager [Y/n]: ',
            )
        ) {
            my $files_to_convert = join( "\n", @ifcfg_files );
            return $self->has_blocker(<<~"EOS");
            The system cannot be elevated to $pretty_distro_name until the legacy network-scripts configuration
            has been converted to use the NetworkManager configuration.  The following files will need to be converted:

            $files_to_convert

            To convert a file, you can run a command similar to the following:

            /usr/bin/nmcli connection migrate /path/to/ifcfg-file

            NOTE: replace /path/to/ifcfg-file with the real path of the file to convert

            EOS
        }
    }

    return;
}

1;
