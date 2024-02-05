package Elevate::Blockers::SSH;

=encoding utf-8

=head1 NAME

Elevate::Blockers::SSH

Blocker to check if the SSH configuration is compliant with the elevate process.

=cut

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use File::Slurper ();
use Log::Log4perl qw(:easy);

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
        OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file, which will default in RHEL8 to "prohibit-password".
        We will set the 'PermitRootLogin' value in $sshd_config to 'yes' before upgrading.

        EOS

        return 0;
    }

    return 1;
}

1;
