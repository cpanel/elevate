package Elevate::Service;

=encoding utf-8

=head1 NAME

Elevate::Service

Class to manage the systemctl service used by the elevate process.

=cut

use cPstrict;

use Cpanel::SafeRun::Simple     ();
use Cpanel::RestartSrv::Systemd ();

use Elevate::Constants ();
use Elevate::OS        ();

use Log::Log4perl qw(:easy);

use Elevate::Roles::Run ();    # for fatpck
use Elevate::Stages     ();

use Simple::Accessor qw{
  name
  file
  short_name
  cpev
};

use parent qw{
  Elevate::Roles::Run
  Elevate::SystemctlService
};

sub _build_name {
    return Elevate::Constants::SERVICE_NAME;
}

sub _build_file ($self) {
    return Elevate::Constants::SERVICE_DIR . '/' . $self->name;
}

sub _build_short_name ($self) {
    my $s = $self->name;
    $s =~ s{\Q.service\E$}{};

    return $s;
}

sub _build_cpev {
    die q[Missing cpev];
}

sub install ($self) {

    my $upgrade_from = Elevate::OS::pretty_name();
    my $upgrade_to   = Elevate::OS::upgrade_to_pretty_name();

    my $name = $self->name;

    INFO( "Installing service $name which will upgrade the server to " . $upgrade_to );
    open( my $fh, '>', $self->file ) or die;

    # When leapp upgrades from AlmaLinux 8 to AlmaLinux 9, it breaks cPanel Perl
    # Due to this, we need to ensure that we have a functioning cPanel Perl
    # before calling elevate-cpanel --service
    print {$fh} <<~"EOF";
        [Unit]
        Description=Upgrade process from $upgrade_from to $upgrade_to.
        After=network.target network-online.target

        [Service]
        Type=simple
        # want to run it once per boot time
        RemainAfterExit=yes
        TimeoutStartSec=15min
        ExecStartPre=-/usr/local/cpanel/scripts/fix-cpanel-perl >/dev/null 2>&1
        ExecStart=/usr/local/cpanel/scripts/elevate-cpanel --service
        Environment="LANG=C"
        Environment="LANGUAGE=C"
        Environment="LC_ALL=C"
        Environment="LC_MESSAGES=C"
        Environment="LC_CTYPE=C"

        [Install]
        WantedBy=multi-user.target
        EOF

    close $fh;

    $self->ssystem_and_die( '/usr/bin/systemctl', 'daemon-reload' );
    $self->ssystem_and_die( '/usr/bin/systemctl', 'enable', $name );

    Elevate::Stages::bump_stage();

    my $pid = fork();
    die qq[Failed to fork: $!] unless defined $pid;
    if ($pid) {
        INFO("Starting service $name");
        return 0;
    }
    else {
        unlink(Elevate::Constants::PID_FILE);    # release the pid so the service can use it
        $self->ssystem_and_die( '/usr/bin/systemctl', 'start', $name );
        exit(0);
    }
}

sub disable ($self) {

    $self->SUPER::disable( 'now' => 0 );
    unlink $self->file;

    return;
}

1;
