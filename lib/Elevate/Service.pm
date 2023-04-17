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

use Log::Log4perl qw(:easy);

use Elevate::Roles::Run ();    # for fatpck

use                            # hide
  Simple::Accessor qw{
  name
  file
  short_name
  cpev
  };

use parent qw{
  Elevate::Roles::Run
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

    my $pretty_distro_name = $self->cpev->upgrade_to_pretty_name();

    my $name = $self->name;

    INFO( "Installing service $name which will upgrade the server to " . $pretty_distro_name );
    open( my $fh, '>', $self->file ) or die;

    # Works only in systemd v240 and newer!
    # StandardOutput=append:/var/log/elevate-cpanel.log
    # StandardError=inherit

    my $log_file = Elevate::Constants::LOG_FILE;

    print {$fh} <<~"EOF";
        [Unit]
        Description=Upgrade process from CentOS 7 to $pretty_distro_name.
        After=network.target network-online.target

        [Service]
        Type=simple
        # want to run it once per boot time
        RemainAfterExit=yes
        ExecStart=/usr/local/cpanel/scripts/elevate-cpanel --service

        [Install]
        WantedBy=multi-user.target
        EOF

    close $fh;

    $self->ssystem_and_die( '/usr/bin/systemctl', 'daemon-reload' );
    $self->ssystem_and_die( '/usr/bin/systemctl', 'enable', $name );

    $self->cpev->bump_stage();

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

sub is_active ( $self, $service = undef ) {

    # cannot trust: `systemctl is-active` with a one-shot service

    $service //= $self->name;

    my $is_active;
    Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/bin/systemctl is-active}, $service );
    $is_active = 1 if $? == 0;

    my $info = Cpanel::RestartSrv::Systemd::get_service_info_via_systemd($service);
    $info->{'ActiveState'} //= '';
    $info->{'SubState'}    //= '';

    $is_active = 1 if $info->{'ActiveState'} eq 'activating' && $info->{'SubState'} eq 'start';

    if ( $is_active && $info->{'SubState'} ne 'exited' ) {
        return 1;
    }

    return 0;
}

sub is_enabled ( $self, $service = undef ) {

    $service //= $self->name;

    my $out = Cpanel::SafeRun::Simple::saferunnoerror( qw{/usr/bin/systemctl is-enabled}, $service ) // '';
    chomp $out;

    return 1 if $out eq 'enabled';

    return 0;
}

sub restart ($self) {
    return $self->ssystem( qw{/usr/bin/systemctl restart}, $self->name );
}

sub remove ($self) {

    $self->ssystem( '/usr/bin/systemctl', 'stop', $self->name );
    $self->disable;

    return;
}

sub disable ($self) {

    $self->ssystem( '/usr/bin/systemctl', 'disable', $self->name );
    unlink $self->file;

    return;
}

1;
