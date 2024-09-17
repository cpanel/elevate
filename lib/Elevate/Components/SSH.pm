package Elevate::Components::SSH;

=encoding utf-8

=head1 NAME

Elevate::Components::SSH

Ensure that the sshd config file has 'PermitRootLogin' set to 'yes'
if it is not set.

=cut

use cPstrict;

use Elevate::Constants ();

use Cwd           ();
use File::Slurper ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {

    my $sshd_config = q[/etc/ssh/sshd_config];

    my $setup = File::Slurper::read_binary($sshd_config) // '';

    # PermitRootLogin is explicitly set, no need for changes
    return if ( $setup =~ m{^\s*PermitRootLogin\b}m );

    # Add ending newline if file does not end with newline
    if ( $setup !~ m{\n$} && length $setup ) {
        $setup .= "\n";
    }

    $setup .= "PermitRootLogin yes\n";

    File::Slurper::write_binary( $sshd_config, $setup );

    return;
}

sub post_distro_upgrade ($self) {

    # Nothing to do
    return;
}

1;
