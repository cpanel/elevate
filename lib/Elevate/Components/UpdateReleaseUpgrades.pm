package Elevate::Components::UpdateReleaseUpgrades;

=encoding utf-8

=head1 NAME

Elevate::Components::UpdateReleaseUpgrades

Update the release-upgrades file in order to allow Ubuntu upgrades

=cut

use cPstrict;

use Elevate::OS ();

use File::Copy    ();
use File::Slurper ();

use Log::Log4perl qw(:easy);

use constant BLOCK_UBUNTU_UPGRADES => q[/usr/local/cpanel/install/BlockUbuntuUpgrades.pm];
use constant RELEASE_UPGRADES_FILE => q[/etc/update-manager/release-upgrades];

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    return unless Elevate::OS::needs_do_release_upgrade();

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    INFO("Removing install script to block upgrades to $pretty_distro_name");
    unlink(BLOCK_UBUNTU_UPGRADES);

    INFO("Updating config file to allow upgrades to $pretty_distro_name");
    my $content = File::Slurper::read_binary(RELEASE_UPGRADES_FILE) // '';
    my @lines   = split "\n", $content;

    my $in_default  = 0;
    my $was_updated = 0;
    foreach my $line (@lines) {

        if ( $line =~ qr{^\s*\[(\w+)\]}a ) {
            if ( $1 eq 'DEFAULT' ) {
                $in_default = 1;
            }
            next;
        }
        next unless $in_default;

        return if $line =~ m{^\s*Prompt\s*=\s*lts}a;

        if ( $line =~ s{^\s*Prompt\s*=\s*(?:normal|never)}{Prompt=lts} ) {
            $was_updated = 1;
            last;
        }
    }

    if ($was_updated) {
        $content = join "\n", @lines;
        $content .= "\n";
        File::Slurper::write_binary( RELEASE_UPGRADES_FILE, $content );
    }

    # Did the file have invalid or bad data to reach this?
    else {
        my $upgrade_file = RELEASE_UPGRADES_FILE;
        my $backup_file  = $upgrade_file . '.pre_elevate';

        INFO( <<~"EOS" );
        Expected line was not found in the config file.  Backing up the config
        file to $backup_file and replacing the contents with the necessary
        config to ensure that the elevate script can upgrade the server.
        EOS

        File::Copy::copy( $upgrade_file, $backup_file );

        my $new_content = <<~'EOS';
        [DEFAULT]
        Prompt=lts
        EOS

        File::Slurper::write_binary( RELEASE_UPGRADES_FILE, $new_content );
    }

    return;
}

sub post_leapp ($self) {

    # Nothing to do
    return;
}

1;
