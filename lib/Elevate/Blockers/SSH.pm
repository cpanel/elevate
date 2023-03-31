package Elevate::Blockers::SSH;

use cPstrict;

use Elevate::Constants ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use File::Slurper ();
use Log::Log4perl qw(:easy);

sub check ($self) {

    return $self->_blocker_invalid_ssh_config;
}

sub _blocker_invalid_ssh_config ($self) {
    return $self->has_blocker(q[Issue with sshd configuration]) unless $self->_sshd_setup();
    return 0;
}

sub _sshd_setup ($self) {
    my $sshd_config = q[/etc/ssh/sshd_config];

    my $setup = eval { File::Slurper::read_binary($sshd_config) } // '';

    if ( $setup !~ m{^\s*PermitRootLogin\b}m ) {
        ERROR( <<~"EOS" );
        OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file, which will default in RHEL8 to "prohibit-password".
        Please set the 'PermitRootLogin' value in $sshd_config before upgrading.
        EOS

        return 0;
    }

    return 1;
}

1;
