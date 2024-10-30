package Elevate::Components::WHM;

=encoding utf-8

=head1 NAME

Elevate::Components::WHM

=head2 check

1. Verify that cPanel is installed
2. Verify that cPanel reports a major version
3. Verify that elevate is supported on the currently reported major version
4. Verify that cPanel is licensed
5. Verify that cPanel is on the latest minor version for the supported major
   version
6. Verify that this is not a sandbox
7. Verify that upcp is not running
8. Verify that backup are not running

=head2 pre_distro_upgrade

noop

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::Notify    ();
use Elevate::OS        ();

use Cpanel::Backup::Sync    ();
use Cpanel::Version::Tiny   ();
use Cpanel::Update::Tiers   ();
use Cpanel::License         ();
use Cpanel::Unix::PID::Tiny ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

use constant BACKUP_ID     => Cpanel::Backup::Sync::BACKUP_TYPE_NEW;
use constant BACKUP_LOGDIR => '/usr/local/cpanel/logs/cpbackup';
use constant UPCP_PIDFILE  => '/var/run/upcp.pid';

sub check ($self) {

    my $ok = 1;

    $ok = 0 unless $self->_blocker_is_missing_cpanel_whm;
    $ok = 0 unless $self->_blocker_is_invalid_cpanel_whm;
    $ok = 0 unless $self->_blocker_is_newer_than_lts;
    $ok = 0 unless $self->_blocker_cpanel_needs_license;
    $ok = 0 unless $self->_blocker_cpanel_needs_update;
    $ok = 0 unless $self->_blocker_is_sandbox;
    $ok = 0 unless $self->_blocker_is_upcp_running;
    $ok = 0 unless $self->_blocker_is_cpanel_backup_running;

    return $ok;
}

sub _blocker_is_missing_cpanel_whm ($self) {
    if ( !-x q[/usr/local/cpanel/cpanel] ) {
        return $self->has_blocker('This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.');
    }

    return 0;
}

sub _blocker_is_invalid_cpanel_whm ($self) {
    if ( !$Cpanel::Version::Tiny::major_version ) {
        return $self->has_blocker('Invalid cPanel & WHM major_version.');
    }

    return 0;
}

sub _blocker_is_newer_than_lts ($self) {

    # Account for dev builds / testing
    my $major = $Cpanel::Version::Tiny::major_version;
    if ( $major != Elevate::OS::lts_supported() && $major != Elevate::OS::lts_supported() - 1 ) {
        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
        return $self->has_blocker(
            sprintf(
                "This version %s does not support upgrades to %s. Please ensure the cPanel version is %s.",
                $Cpanel::Version::Tiny::VERSION_BUILD,
                $pretty_distro_name,
                Elevate::OS::lts_supported(),
            )
        );
    }

    return 0;
}

sub _blocker_cpanel_needs_license ($self) {
    return 0 if Cpanel::License::is_licensed( skip_max_user_check => 1 );

    require Cpanel::DIp::MainIP;
    require Cpanel::NAT;

    my $localip  = Cpanel::DIp::MainIP::getmainip()     // '';
    my $publicip = Cpanel::NAT::get_public_ip($localip) // '';

    my $ip_msg = "";

    if ($publicip) {
        $ip_msg = <<~EOS;
        cPanel expects to find a license for the IP address $publicip.
        Verify whether that IP address is licensed using the following site:

        https://verify.cpanel.net/
        EOS
    }
    else {
        $ip_msg = <<~'EOS';
        Additionally, cPanel cannot determine which IP address is being used for licensing.
        EOS
    }

    return $self->has_blocker( <<~EOS );
    cPanel does not detect a valid license for itself on the system at this
    time. This could cause problems during the update.

    $ip_msg
    EOS
}

sub _blocker_cpanel_needs_update ($self) {
    if ( !$self->getopt('skip-cpanel-version-check') ) {
        my $lts_supported    = Elevate::OS::lts_supported();
        my $tiers_obj        = Cpanel::Update::Tiers->new( logger => Log::Log4perl->get_logger(__PACKAGE__) );
        my $expected_version = $tiers_obj->get_flattened_hash()->{"11.$lts_supported"};
        if ( !Cpanel::Version::Compare::compare( $Cpanel::Version::Tiny::VERSION_BUILD, '==', $expected_version ) ) {
            return $self->has_blocker( <<~"EOS" );
            This installation of cPanel ($Cpanel::Version::Tiny::VERSION_BUILD) does not appear to be up to date.
            Please upgrade cPanel to $expected_version.
            EOS
        }
    }
    else {
        Elevate::Notify::warn_skip_version_check();
    }

    return 0;
}

sub _blocker_is_sandbox ($self) {
    if ( -e q[/var/cpanel/dev_sandbox] ) {
        return $self->has_blocker('Cannot elevate a sandbox...');
    }

    return 0;
}

sub _blocker_is_upcp_running ($self) {
    return 0 unless $self->getopt('start');

    my $upid = Cpanel::Unix::PID::Tiny->new();

    my $upcp_pid = $upid->get_pid_from_pidfile(UPCP_PIDFILE);

    if ($upcp_pid) {

        $self->components->abort_on_first_blocker(1);

        return $self->has_blocker( <<~"EOS");
        cPanel Update (upcp) is currently running. Please wait for the upcp (PID $upcp_pid) to complete, then try again.
        You can use the command 'ps --pid $upcp_pid' to check if the process is running.
        EOS
    }

    return 0;
}

sub _blocker_is_cpanel_backup_running ($self) {
    return 0 unless $self->getopt('start');

    if ( !Cpanel::Backup::Sync::handle_already_running( BACKUP_ID, BACKUP_LOGDIR, Log::Log4perl->get_logger(__PACKAGE__) ) ) {

        $self->components->abort_on_first_blocker(1);

        # Cpanel::Backup::Sync::handle_already_running will log the PID and log file location for the backup
        # so there is no need for us to do that in the blocker message
        return $self->has_blocker( <<~'EOS');
        A cPanel backup is currently running. Please wait for the cPanel backup to complete, then try again.
        EOS
    }

    return 0;
}

1;
