package Elevate::Components::SSH;

=encoding utf-8

=head1 NAME

Elevate::Components::SSH

=head2 check

Check that PermitRootLogin setting is explicitely set in sshd_config since the
default for this config option changes on upgraded systems

=head2 pre_distro_upgrade

Explicitely set PermitRootLogin to yes if it was not explicitely set in the
check

=head2 post_distro_upgrade

noop

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

sub check ($self) {

    return $self->_check_ssh_config();
}

sub _check_ssh_config ($self) {
    my $sshd_config = q[/etc/ssh/sshd_config];

    my $setup = eval { File::Slurper::read_binary($sshd_config) } // '';
    if ( my $exception = $@ ) {
        ERROR("The system could not read the sshd config file ($sshd_config): $exception");
        return $self->has_blocker(qq[Unable to read the sshd config file: $sshd_config]);
    }

    if ( $setup !~ m{^\s*PermitRootLogin\b}m ) {
        WARN( <<~"EOS" );
        OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file; this may default to "prohibit-password" after upgrading the distro.
        We will set the 'PermitRootLogin' value in $sshd_config to 'yes' before upgrading.

        EOS

        return 0;
    }

    return 1;
}

1;
