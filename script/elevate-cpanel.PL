#!/usr/local/cpanel/3rdparty/bin/perl

# Copyright 2023 cPanel L.L.C.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.

package cpev;

=encoding utf8

=head1 NAME

/scripts/elevate-cpanel

=head1 DESCRIPTION

Helps to upgrade CentOS 7 cPanel servers to AlmaLinux 8 or Rocky Linux 8.

=head1 SYNOPSIS

    /scripts/elevate-cpanel [OPTIONS]

    Optional:
       --start                        Start the convertion process
       --continue                     Continue the convertion: retry the last step
       --check[=BLOCKER_FILE]         Check if your system has any known blockers to upgrade.
       --log                          Show the current elevation log
       --status                       Check the current elevation status
       --clean                        Cleanup scripts and files created by elevate-cpanel
       --upgrade-to=[rocky|almalinux] Update to AlmaLinux 8 or Rocky Linuyx 8
                                      [default to 'almalinux']

       --update                       Instruct the script to replace itself on disk with a downloaded copy of the latest version.
       --version                      Print the version number and exit.

       --skip-elevate-version-check   Skip the check for whether this script is up to date.
       --skip-cpanel-version-check    Skip the check for whether cPanel is up to date.
                                      This option is intended only for testing!

       --help                         Display this documentation.

=head1 COMMON USAGE

=over

=item Start an installation

You can start an elevation update by running:

    # AlmaLinux 8 update
    /scripts/elevate-cpanel --start
    /scripts/elevate-cpanel --start --upgrade-to=almalinux

    # Rocky Linux 8 update
    /scripts/elevate-cpanel --start --upgrade-to=rocky

=item Compatibility check with elevation

You can check if your server is compatible with the upgrade process without
starting an upgrade process.

    # Check AlmaLinux 8 update
    /scripts/elevate-cpanel --check
    /scripts/elevate-cpanel --check --upgrade-to=almalinux

    # Check Rocky Linux 8 update
    /scripts/elevate-cpanel --check --upgrade-to=rocky

This will also save a JSON representation of the blockers to a file, C</var/cpanel/elevate-blockers> by default,
but passing an optional argument will use the file given instead:

    /scripts/elevate-cpanel --check /root/blockers.json

=item Start an installation with manual reboot

You can control the reboots by using the --manual-reboots flag when starting the process.
This can be used for debugging purpose.

    /scripts/elevate-cpanel --start --manual-reboots

=item Monitor an existing installation

Once you have started an elevation process, you can check the current update by running:

    /scripts/elevate-cpanel

You can also check the current status by running

    /scripts/elevate-cpanel --status

You can check and monitor the elevation log

    /scripts/elevate-cpanel --log

=item Resume an installation after an error

If an error occurs during the elevation process, once you have fixed it, you can resume
the update process by running:

    /scripts/elevate-cpanel --continue

=back

=head1 WARNINGS

The elevation process from CentOS 7 to AlmaLinux 8 or Rocky Linux 8 distribution
is not a risk free update.
Depending on the state of your current distribution multiple errors can occur.
We recommend updating your system to the last upstream state before starting.

The elevation process can take several long minutes and requires multiple reboots.
Some reboots are expected to be longer than normal.

Please do not interrupt the reboots and elevation process.

=cut

use cPstrict;

use Elevate::Constants ();

BEGIN {
    # sanity check before loading the script
    eval { require Cpanel::Version::Tiny } or do {
        warn(qq[This script is designed to only run on cPanel servers.\n]);
        exit 1;
    };

    $Cpanel::Version::Tiny::major_version >= Elevate::Constants::MINIMUM_LTS_SUPPORTED
      or do {
        warn qq[You need to upgrade your cPanel server to version ] . Elevate::Constants::MINIMUM_LTS_SUPPORTED    #
          . qq[or later before running this script.\n];
        exit 1;
      };
}

use Log::Log4perl qw(:easy);

use Config;
use Carp                  ();
use Errno                 ();
use File::Basename        ();
use File::Copy            ();
use File::Copy::Recursive ();
use File::Find            ();
use File::Path            ();
use File::Slurper         ();
use File::Spec            ();
use File::Temp            ();
use Hash::Merge           ();
use Term::ANSIColor       ();

use Cpanel::AccessIds::SetUids  ();
use Cpanel::Binaries            ();
use Cpanel::Config::Httpd       ();
use Cpanel::Config::LoadCpConf  ();
use Cpanel::JSON                ();
use Cpanel::OS                  ();
use Cpanel::PID                 ();
use Cpanel::Pkgr                ();
use Cpanel::RestartSrv::Systemd ();
use Cpanel::SafeRun::Simple     ();
use Cpanel::SafeRun::Errors     ();
use Cpanel::SafeRun::Object     ();
use Cpanel::Update::Tiers       ();
use Cpanel::Version::Tiny       ();
use Cpanel::Version::Compare    ();
use Cpanel::Yum::Vars           ();

# FatPack these packages
# - fatpack blockers
use Elevate::Blockers::Base          ();
use Elevate::Blockers                ();
use Elevate::Blockers::Databases     ();
use Elevate::Blockers::DiskSpace     ();
use Elevate::Blockers::Distros       ();
use Elevate::Blockers::DNS           ();
use Elevate::Blockers::EA4           ();
use Elevate::Blockers::ElevateScript ();
use Elevate::Blockers::Grub2         ();
use Elevate::Blockers::IsContainer   ();
use Elevate::Blockers::JetBackup     ();
use Elevate::Blockers::NICs          ();
use Elevate::Blockers::OVH           ();    # using a constant
use Elevate::Blockers::Repositories  ();    # using a constant
use Elevate::Blockers::SSH           ();
use Elevate::Blockers::WHM           ();

# - fatpack Components
use Elevate::Components::Base       ();
use Elevate::Components::EA4        ();
use Elevate::Components::Grub2      ();
use Elevate::Components::KernelCare ();
use Elevate::Components::MySQL      ();

use Elevate::Fetch            ();
use Elevate::Logger           ();
use Elevate::Motd             ();
use Elevate::Notify           ();
use Elevate::Roles::Run       ();    # used as parent, but ensure fatpack
use Elevate::Script           ();
use Elevate::Service          ();
use Elevate::SystemctlService ();
use Elevate::Usage            ();

#<<V *** DO NOT EDIT THESE LINES MANUALLY ***
use constant VERSION => 7;
#>>V *** DO NOT EDIT THESE LINES MANUALLY ***

use constant CHKSRVD_SUSPEND_FILE => q[/var/run/chkservd.suspend];
use constant ELEVATE_STAGE_FILE   => '/var/cpanel/elevate';
use constant ELEVATE_SUCCESS_FILE => '/var/cpanel/version/elevate';
use constant ELEVATE_BACKUP_DIR   => "/root/.elevate.backup";

use constant VALID_STAGES        => 5;
use constant DISTRO_PERL_XS_PATH => '/usr/local/lib64/perl5';

use constant IGNORE_OUTDATED_SERVICES_FILE => q[/etc/cpanel/local/ignore_outdated_services];

use constant LEAPP_REPORT_JSON => q[/var/log/leapp/leapp-report.json];
use constant LEAPP_REPORT_TXT  => q[/var/log/leapp/leapp-report.txt];

use constant NOC_RECOMMENDATIONS_TOUCH_FILE => q[/var/cpanel/elevate-noc-recommendations];

use constant IMUNIFY_AGENT          => '/usr/bin/imunify360-agent';
use constant IMUNIFY_LICENSE_FILE   => '/var/imunify360/license.json';
use constant IMUNIFY_LICENSE_BACKUP => ELEVATE_BACKUP_DIR . '/imunify-backup-license.json';

# XXX TODO verify that imunify reponames are in fact correct.
# As of now they are straight up guesses.

use constant REBOOT_NEEDED => 4242;    # just one unique id

# prefer string over integers so we can read the configuration file (no need for bitmask)
use constant UPGRADE_TO_ALMALINUX => q[AlmaLinux];
use constant UPGRADE_TO_ROCKY     => q[Rocky];

use Simple::Accessor qw{
  service
  script
  blockers

  _abort_on_first_blocker
};

# after Simple::Accessor
use parent qw{
  Elevate::Roles::Run
  Elevate::Usage
};

exit( __PACKAGE__->run(@ARGV) // 0 ) unless caller;

sub _build_service ($self) {

    # FIXME weaken
    return Elevate::Service->new( cpev => $self );
}

sub _build_blockers ($self) {

    # FIXME weaken
    return Elevate::Blockers->new( cpev => $self );
}

sub _build_script ($self) {
    return Elevate::Script->new;
}

sub _init ( $self_or_pkg, @args ) {

    my $self = ref $self_or_pkg ? $self_or_pkg : $self_or_pkg->new;

    Elevate::Usage::init( $self, @args );
    Elevate::Logger::init($self);

    return $self;
}

sub run ( $pkg, @args ) {

    local $| = 1;

    my $self = _init( $pkg, @args );

    if ( $self->getopt('version') ) {
        say VERSION;
        return 0;
    }

    if ( $self->getopt('update') ) {
        return $self->do_update();
    }

    $self->_parse_opt_upgrade_to();

    if ( $self->getopt('start') ) {
        die qq[Unsupported option with --start\n] if $self->getopt('continue') || $self->getopt('service');
        return 1                                  if $self->start();
    }
    elsif ( $self->getopt('status') ) {
        return $self->check_status();
    }

    return $self->do_cleanup()      if $self->getopt('clean');
    return $self->blockers->check() if defined $self->getopt('check');

    my $stage = get_stage();

    if ( $stage == 0 ) {
        print_box("Please re-run this script with --start if you would like to begin the upgrade process");
        return $self->full_help(1);    # exit
    }

    if ( $self->getopt('start') || $self->getopt('log') ) {
        1;                             # these options are exclusive
    }
    elsif ( $self->getopt('continue') ) {
        $self->continue_elevation();
    }
    elsif ( $self->getopt('service') ) {

        # running from the systemct service
        return $self->run_service_and_notify();
    }

    monitor_upgrade();

    return 0;
}

sub component ( $self, $name ) {    # FIXME -> get_compoment
    my $pkg = qq[Elevate::Components::$name];

    # my $sub = $pkg->can( 'new' ) or die qq[Missing new from $pkg];
    # my $x = $sub->( $pkg, cpev => $self );
    # return $x;
    return $pkg->new( cpev => $self );
}

sub get_blocker ( $self, $name ) {    # helper for tests
    $self->blockers->_get_blocker_for($name);
}

sub _parse_opt_upgrade_to ($self) {

    return unless my $flavor = $self->getopt('upgrade-to');

    if ( !defined $self->getopt('start') && !defined $self->getopt('check') ) {
        die qq[--upgrade-to option is only supported with --start or --check\n];
    }
    $flavor = lc $flavor;
    if ( $flavor !~ m{^(?:almalinux|alma|rocky)$} ) {
        die qq[Invalid --upgrade_to value '$flavor'. Only 'almalinux' or 'rocky' are supported.\n];
    }

    $self->{upgrade_to} = $flavor eq 'rocky' ? UPGRADE_TO_ROCKY : UPGRADE_TO_ALMALINUX;

    return;
}

sub do_update ($self) {

    INFO( "Self-update of script version " . VERSION . " requested." );

    my ( $needs_update, undef ) = $self->script->is_out_of_date();

    if ($needs_update) {
        INFO("Newer version of script found. Downloading.");
        my $temp_file = $self->script->fetch;
        return 1 unless $temp_file;    # Elevate::Fetch::script handled the error msg

        my $running_from = Cwd::abs_path($0) // '';
        if ( File::Copy::move( $temp_file, $running_from ) ) {
            chmod 0700, $running_from;
            my $confirmed_version = Cpanel::SafeRun::Simple::saferunnoerror( $running_from, '--version' );
            chomp $confirmed_version;
            INFO("Script update to version $confirmed_version successful.");
        }
        else {
            ERROR("The system could not replace the existing copy of the script: $!");
            return 1;
        }
    }
    else {
        INFO("Script is up to date.");
    }

    return 0;
}

sub upgrade_to ($self) {    # main helper to know the upgrade_to distro
    return $self->{upgrade_to} if $self->{upgrade_to};
    return read_stage_file( 'upgrade_to', UPGRADE_TO_ALMALINUX );    # default to AlmaLinux
}

sub upgrade_to_rocky ($self) {
    return $self->upgrade_to() eq UPGRADE_TO_ROCKY;
}

sub upgrade_to_pretty_name ($self) {    # used by output messages
    return q[Rocky Linux 8] if $self->upgrade_to_rocky;
    return q[AlmaLinux 8];
}

sub monitor_upgrade {
    my $stage = get_stage();

    INFO( "# Monitoring existing upgrade (stage=$stage) process via: tail -f " . Elevate::Constants::LOG_FILE );

    exec( qw{/usr/bin/tail -n40 -F }, Elevate::Constants::LOG_FILE );
}

sub start ($self) {
    Elevate::Blockers::Distros::bail_out_on_inappropriate_distro();
    my $stage = get_stage();
    if ( $stage != 0 ) {
        my $header;
        if ( $stage > VALID_STAGES ) {
            $header = q[The 'elevate-cpanel' script has already been executed on this server.];
        }
        else {
            $header = qq[An elevation process is currently in progress: running stage $stage];
        }

        die <<~"EOS";
        $header
        You can check the log by running:
            /scripts/elevate-cpanel --log
        or check the elevation status:
            /scripts/elevate-cpanel --check
        EOS

    }

    $self->give_last_chance();

    system touch => Elevate::Constants::LOG_FILE;

    $self->bump_stage();    # init stage number to 1

    # store the manual reboots flag
    if ( $self->getopt('manual-reboots') ) {
        WARN('Manual Reboot would be required between each stages');
        update_stage_file( { manual_reboots => 1 } );
    }

    # prefer over running step1: so status and notifications are enabled
    return $self->run_service_and_notify();
}

# This code used to be in stage 1, but it makes more sense for it to take place before a stage has been set.
sub give_last_chance ($self) {

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    print_box(qq[/!\ Warning: You are about to convert your cPanel & WHM CentOS 7 to $pretty_distro_name server.]);

    present_noc_recommendations();

    say <<'EOS';

The elevation process can take several long minutes and requires multiple reboots.
Some reboots can be longer than normal, please do not interrupt the process.

Please *do not interrupt* the reboots and elevation process.

You can check at any time the current status of the update by running:

    /scripts/elevate-cpanel

On failures after fixing them you can continue the elevation process by running:

    /scripts/elevate-cpanel --continue

EOS

    Elevate::Notify::warn_skip_version_check() if $self->getopt('skip-cpanel-version-check');    # give one last reminder

    say <<EOS;
This is your chance now to cancel the update process.
You can hit CTRL-C to abort, otherwise the install starts in a few seconds.
EOS

    do { sleep 1; print '.' }
      for 1 .. 6;
    print "\n";

    return;
}

sub continue_elevation ($self) {

    if ( $self->service->is_active ) {
        WARN( "The service " . $self->service->name . " is still running. Please wait for it to finish before restarting it." );
        return;
    }

    # check that no process is running and remove the pidfile for the other
    $self->check_and_create_pidfile()->remove_pid_file;

    my $pid = fork();
    LOGDIE(qq[Failed to fork: $!]) unless defined $pid;
    if ($pid) {
        INFO("Restarting install process");
        return 1;
    }
    else {
        # when restarting leapp process the restart process can hang for a long time
        #   return earlier to let the user tail the service log
        $self->service->restart;
        exit(0);
    }
}

sub do_cleanup ($self) {

    $self->service->remove;

    $self->ssystem( '/usr/bin/systemctl', 'daemon-reload' );
    unlink ELEVATE_STAGE_FILE;
    unlink Elevate::Constants::PID_FILE;

    unlink Elevate::Blockers::OVH::OVH_MONITORING_TOUCH_FILE;

    Elevate::Motd->cleanup();

    return 0;
}

sub run_service_and_notify ($self) {    # FIXME: move to Elevate::Service - need Notify

    # check it outside the eval block to avoid notification from the command line
    $self->check_and_create_pidfile();

    my $stage = get_stage();

    update_stage_file( { status => q[running] } ) if $stage >= 2;

    my $out;
    my $ok = eval {
        $out = $self->_run_service();
        1;
    };

    if ($ok) {

        # only notify a success when reaching the last stage
        if ( $stage == VALID_STAGES ) {
            update_stage_file( { status => q[success] } );
            $self->_notify_success();
        }

        $self->reboot() if $out == REBOOT_NEEDED;
    }
    else {
        my $error = $@ // q[Unknown error];

        update_stage_file( { status => q[failed] } );
        $self->_notify_error($error);

        LOGDIE($error);
    }

    return $out;
}

sub check_and_create_pidfile ($self) {
    my $upid = Cpanel::PID->new( { pid_file => Elevate::Constants::PID_FILE } );

    if ( $upid->create_pid_file() != 1 ) {
        die qq[Another process is already running. Please wait for it to finish.\n];
    }

    return $upid;
}

sub check_status ($self) {
    my $stage = get_stage();

    if ( !$stage ) {
        ERROR('Elevation process has not started yet.');
        return;
    }

    my $status = read_stage_file( 'status', 'unknown' );

    if ( $status eq 'success' ) {
        say q[success];
    }
    elsif ( $status eq 'running' ) {
        say qq[Running stage $stage / ] . VALID_STAGES;
    }
    elsif ( $status eq 'failed' ) {
        say qq[Failed during stage $stage];
    }
    else {
        say q[Unknown status];
        return 1;
    }

    return;
}

sub add_final_notification ( $msg, $warn_now = 0 ) {
    my $stage_info = read_stage_file();

    return unless defined $msg && length $msg;

    update_stage_file( { final_notifications => [$msg] } );    # stacked to the previously stored

    if ($warn_now) {
        foreach my $l ( split( "\n", $msg ) ) {
            next unless length $l;
            WARN($l);
        }
    }

    return 1;
}

sub _notify_success ($self) {

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    my $msg = <<"EOS";
The cPanel & WHM server has completed the elevation process from CentOS 7 to $pretty_distro_name.
EOS

    if ( my $warnings = read_stage_file( 'final_notifications', [] ) ) {
        if ( scalar @$warnings ) {
            $msg .= "\nThe update to $pretty_distro_name was successful but please note that one ore more notifications require your attention:\n";

            foreach my $w ( reverse @$warnings ) {    # restore insert order
                $msg .= "\n* $w\n";
            }
        }
    }

    send_notification( qq[Successfully updated to $pretty_distro_name] => $msg, is_success => 1 );

    return;
}

sub _notify_error ( $self, $error = '' ) {

    my $stage = get_stage();

    my $msg = <<"EOS";
The elevation process failed during stage $stage.

You can continue the process after fixing the errors by running:

    $0 --continue

You can check the error log by running:

    $0

Last Error:

$error

EOS

    my $pretty_distro_name = $self->upgrade_to_pretty_name();
    send_notification( qq[Fail to update to $pretty_distro_name] => $msg );

    return;
}

sub send_notification ( $subject, $msg, %opts ) {

    eval {
        _send_notification( $subject, $msg, %opts );
        1;
    }
      or warn "Fail to send notification: $@";

    return;
}

sub _send_notification ( $subject, $msg, %opts ) {

    my $is_success = delete $opts{is_success};

    # note: no need to use one iContact::Class this is a one shot message
    require Cpanel::iContact;

    INFO("Sending notification: $subject");

    my $log   = $is_success ? \&INFO : \&ERROR;
    my @lines = split( "\n", $msg );
    foreach my $line (@lines) {
        $log->($line);
    }

    Cpanel::iContact::icontact(
        'application' => 'elevate',
        'subject'     => $subject,
        'message'     => $msg,
    );

    return;
}

sub _run_service ($self) {

    my $stage = get_stage();

    print_box( "Starting stage $stage of " . VALID_STAGES ) if $stage > 1;

    # sanity check
    if ( Cpanel::OS::major() == 8 && 2 <= $stage && $stage <= 3 ) {
        WARN( "Detected " . Cpanel::OS::pretty_distro() . " while running stage $stage: swtiching to stage 4" );
        $stage = 4;
        _update_stage_number($stage);
    }

    return $stage == 1
      ? $self->run_stage_1()                                                       # Sanity check & install elevate service
      : $stage == 2 ? $self->run_stage_2()                                         # Update the current distro packages then reboot
      : $stage == 3 ? $self->run_stage_3()                                         # Prep leapp & run leapp process
      : $stage == 4 ? $self->run_stage_4()                                         # reboot on AlmaLinux 8: restore packages
      : $stage == 5 ? $self->run_stage_5()                                         # Final checks and cleanup
      :               die "Unknown stage '$stage'. I don't know how to proceed";

}

sub present_noc_recommendations () {
    local $!;

    my $default_msg = <<~EOS;
    Your server provider has requested that you contact their technical support
    for additional information before you continue with this upgrade process.
    EOS

    my $can_read_file = open( my $fh, '<', NOC_RECOMMENDATIONS_TOUCH_FILE );

    if ( $can_read_file || $! != Errno::ENOENT ) {
        WARN "Provider advisory file potentially present but unable to be opened for reading ($!): using default notice." unless $can_read_file;

        my $msg;
        if ($fh) {
            local $/;
            $msg = <$fh>;
        }
        $msg ||= $default_msg;
        say $msg;

        print "Proceed with the upgrade process? (yes/no) ";
        my $reply = lc <STDIN>;
        chomp $reply;

        if ( $reply !~ m/^y(?:es?)?$/ ) {
            FATAL "Provider recommendations not acknowledged.";
            exit 1;
        }

        INFO "Provider recommendations acknowledged; continuing.";
    }

    close $fh if $fh;
    return 1;
}

=head1 STAGES

Description of the multiple stages used during the elevation process.
Between each stage a reboot is performed before doing a final reboot at the very end.

=head2 run_stage_1

Start the elevation process by installing the elevate-cpanel service
responsible of the multiple reboots.

=cut

sub run_stage_1 ($self) {

    # do not leave cruft behing when aborting
    my $abort = sub {
        $self->do_cleanup();
        exit 42;    ## no critic(Cpanel::NoExitsFromSubroutines) catching signals
    };

    local $SIG{'INT'} = $abort;
    local $SIG{'HUP'} = $abort;

    return 1 unless _sanity_check();

    if ( $self->blockers->check() ) {

        # we have not yet install the service yet, clear the stage file
        $self->service->remove;
        return 1;
    }

    print_box( "Starting stage 1 of " . VALID_STAGES . ": Installing " . $self->service->name . " service" );

    # store 'upgrade_to' early so later stages can access it
    update_stage_file( { upgrade_to => $self->upgrade_to } );

    return $self->service->install();
}

=head2 run_stage_2

Update the current distro packages then reboot.

=cut

sub run_stage_2 ($self) {

    my $sum = `/usr/bin/md5sum $0`;
    chomp $sum;
    DEBUG( sprintf( "Running $0 (%s/%s)", -s $0, $sum ) );

    $self->elevation_startup_marker($sum);

    $self->ssystem(qw{/usr/bin/yum clean all});
    $self->ssystem_and_die(qw{/scripts/update-packages});
    $self->ssystem_and_die(qw{/usr/bin/yum -y update});

    $self->disable_all_cpanel_services();

    $self->setup_outdated_services();

    system touch => CHKSRVD_SUSPEND_FILE;

    Elevate::Motd->setup();

    $self->run_component_once( 'KernelCare' => 'pre_leapp' );
    $self->run_component_once( 'Grub2'      => 'pre_leapp' );

    return REBOOT_NEEDED;
}

=head2 run_stage_3

Setup the AlmaLinux elevate-release-latest-el7 repo and install leapp packages.
Prepare the cPanel packages for the update.

Remove some known conflicting packages. (Reinstall later).

Provide answers to a few leapp questions.

Attempt to perform the leapp upgrade itself.
In case of failure you probably want to reply to a few extra questions or remove some conflicting packages.

=cut

sub run_stage_3 ($self) {

    $self->run_once(
        prep_for_leapp => sub {

            $self->run_once(
                install_pkgs => sub {
                    unless ( Cpanel::Pkgr::is_installed('elevate-release') ) {

                        # provides leapp-data-almalinux & leapp-data-rocky
                        $self->ssystem_and_die(qw{/usr/bin/yum install -y http://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm});
                    }

                    my $leap_data_pkg = $self->upgrade_to_rocky() ? 'leapp-data-rocky' : 'leapp-data-almalinux';

                    unless ( Cpanel::Pkgr::is_installed('leapp-upgrade') && Cpanel::Pkgr::is_installed($leap_data_pkg) ) {
                        $self->ssystem_and_die( qw{/usr/bin/yum install -y leapp-upgrade }, $leap_data_pkg );
                    }
                    if ( Cpanel::Pkgr::is_installed('kernel-devel') ) {
                        $self->ssystem_and_die(qw{/usr/bin/yum -y remove kernel-devel});
                    }

                    return;
                }
            );

            $self->run_once(
                rmod_ln => sub {
                    $self->ssystem( '/usr/sbin/rmmod', $_ ) foreach qw/floppy pata_acpi/;
                    $self->ssystem(qw{/usr/bin/ln -snf usr/local/cpanel/scripts /scripts});

                    return;
                }
            );

            # We have to do this before removing the rpms.
            $self->run_once('pre_leapp_update_backup_and_cleanup');

            # remove all arch cpanel packages
            # This also potentially removes
            $self->ssystem(q{/usr/bin/rpm -e --justdb --nodeps `/usr/bin/rpm -qa | /usr/bin/egrep '^cpanel-.*\.x86_64'`});

            # remove all ea- packages
            $self->ssystem(q{/usr/bin/yum -y erase ea-*});

            foreach my $rpm (qw/ yum-plugin-fastestmirror epel-release/) {
                next unless Cpanel::Pkgr::is_installed($rpm);
                $self->ssystem( '/usr/bin/rpm', '-e', '--nodeps', $rpm );
            }

            # Avoids having to do preupgrade.
            setup_answer_file();

            return;
        }
    );

    $self->_do_leapp_upgrade();

    WARN(<<'EOS');
Rebooting for distro upgrade. This will take over 10 minutes to run.
Do not interrupt power during this event or you will corrupt your system.
EOS

    return REBOOT_NEEDED;

    # This takes a while because on reboot it's installing 800 packages
}

=head2 run_stage_4

At this stage we should now run Alamalinux 8.
Update cPanel product for the new distro.

Restore removed packages during the previous stage.

=cut

sub run_stage_4 ($self) {
    Cpanel::OS::flush_disk_caches();

    if ( Cpanel::OS::major() != 8 ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        my $current_distro     = Cpanel::OS::pretty_distro();

        if ( Cpanel::OS::major() == 7 ) {
            WARN("Detected $current_distro from stage 4, reverting back to stage 3.");
            _update_stage_number(3);
        }

        die( <<~"END");
        Server is currently running $current_distro after leapp upgrade.
        Upgrade to $pretty_distro_name did not succeed.

        Please review your upgrade logs and correct the problem.
        `leapp` logs are located at:
            /var/log/leapp/leapp-report.txt
            /var/log/leapp/leapp-report.json

        Once you believe you have corrected the problem you can continue the upgrade process
        by running:
            /scripts/elevate-cpanel --continue
        END
    }

    my $stash = read_stage_file();

    $stash->{stage4} //= {};    # run once each blocks

    $self->run_once(
        sysup => sub {
            Cpanel::Yum::Vars::install();
            $self->ssystem_and_die(qw{/usr/bin/dnf clean all});

            # no failures once already installed: no need to check for the epel-release version
            $self->ssystem_and_die(qw{/usr/bin/dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm});

            $self->ssystem(qw{/usr/bin/rm -f /usr/local/cpanel/3rdparty/bin/perl});
            {
                local $ENV{'CPANEL_BASE_INSTALL'} = 1;    # Don't fix more than perl itself.
                $self->ssystem(qw{/usr/local/cpanel/scripts/fix-cpanel-perl});
            }
            $self->ssystem(qw{/usr/bin/dnf -y --allowerasing update});
            $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/sysup});

            return;
        }
    );

    $self->run_once(
        restore_cpanel_services => sub {
            $self->enable_all_cpanel_services();
            $self->stop_services_before_upcp();
            $self->clear_cpanel_caches();

            return;
        }
    );

    $self->run_component_once( 'EA4' => 'restore' );

    $self->run_once(
        upcp => sub {

            {
                # MySQL server is not upgraded at this point - treat the upcp like a fresh install
                local $ENV{'CPANEL_BASE_INSTALL'} = 1;
                $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/upcp --sync});
            }

            # cleanup the license: cpsanitycheck.so binary is compiled for a different distro
            $self->ssystem(qw{/usr/bin/rm -f /usr/local/cpanel/cpsanitycheck.so});
            $self->ssystem(qw{/usr/local/cpanel/cpkeyclt});

            return;
        }
    );

    $self->post_leapp_update_restore();

    my @known_modules_that_dont_convert = qw{libtermkey msgpack btrfs-progs elevate-release
      leapp leapp-data-almalinux leapp-data-rocky leapp-upgrade-el7toel8
      python2-leapp alt-pcre802 alt-pcre802-devel};
    my @to_remove = grep { Cpanel::Pkgr::is_installed($_) } @known_modules_that_dont_convert;

    INFO("Removing known cruft that various 3rdparties leave behind. Also removing leapp.");
    $self->ssystem( qw{/usr/bin/dnf -y erase}, @to_remove );

    # run upcp a second time as we had to run it before with CPANEL_BASE_INSTALL=1
    $self->run_once(
        upcp_second_run => sub {
            $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/upcp --sync});
        }
    );

    return REBOOT_NEEDED;
}

=head2 run_stage_5

Final checks and cleanup.
The elevate-cpanel service is now removed.

=cut

sub run_stage_5 ($self) {
    return 1 if $self->post_upgrade_check();

    # we cannot stop the service ( ourself )
    $self->service->disable;
    unlink Elevate::Constants::PID_FILE;
    unlink CHKSRVD_SUSPEND_FILE;
    File::Path::remove_tree(ELEVATE_BACKUP_DIR) if -d ELEVATE_BACKUP_DIR;
    Elevate::Motd->cleanup();

    $self->run_component_once( 'Grub2' => 'post_leapp' );

    my $final_notifications = read_stage_file( 'final_notifications', [] );
    if (@$final_notifications) {

        print_box("Final Notifications");

        my $final_notice = "The following recommendations should now be reviewed for further action:";

        foreach my $msg ( reverse @$final_notifications ) {
            $final_notice .= "\n$msg\n";
        }
        add_final_notification( $final_notice, 1 );
    }

    $self->elevation_success_marker();

    $self->restore_outdated_services();

    INFO("Updating all packages before final reboot");
    $self->ssystem(qw{/usr/bin/dnf -y --allowerasing update});

    my $pretty_distro_name = $self->upgrade_to_pretty_name();
    print_box("Great SUCCESS! Your upgrade to $pretty_distro_name is complete.");

    return REBOOT_NEEDED;
}

sub _bq_now () {
    require POSIX;
    return POSIX::strftime( '%FT%T', gmtime );
}

sub elevation_startup_marker ( $self, $sum = 'unknown' ) {

    # store some generic informations about the update process
    update_stage_file(
        {
            '_elevate_process' => {
                script_md5            => $sum,
                cpanel_build          => $Cpanel::Version::Tiny::VERSION_BUILD,
                started_at            => _bq_now(),
                redhat_release_pre    => read_redhat_release(),
                elevate_version_start => VERSION,
            }
        }
    );

    return;
}

sub elevation_success_marker ($self) {

    update_stage_file(
        {
            '_elevate_process' => {
                finished_at            => _bq_now(),
                redhat_release_post    => read_redhat_release(),
                elevate_version_finish => VERSION,
            }
        }
    );

    File::Copy::copy( ELEVATE_STAGE_FILE, ELEVATE_SUCCESS_FILE );

    return;
}

=pod

Example:

    $self->run_component_once( Imunify => 'backup' );

=cut

sub run_component_once ( $self, $name, $function ) {

    my $component = $self->component($name);
    my $label     = "compoment:$name:$function";
    my $sub       = $component->can($function)     #
      or die qq[Missing functon $function from component '$name'];

    my $run = sub {
        return $sub->($component);
    };

    return $self->run_once( $label, $run );
}

sub run_once ( $self, $label, $code = undef ) {

    die unless defined $label;

    $code //= cpev->can($label) or die qq[Missing function '$label'];

    die unless ref $code eq 'CODE';

    my $current_stage = get_stage() or die q[Unknown stage id];
    my $stage_name    = 'stage' . $current_stage;

    my $stash = read_stage_file();
    $stash->{'_run_once'} //= {};

    my $full_label = $stage_name . '_' . $label;

    # already run one time successfully
    if ( $stash->{'_run_once'}->{$full_label} ) {
        INFO( sprintf( "Stage %d: skipping %s (already run)", $current_stage, $label ) );
        return 1;
    }

    $code->($self);

    # successfully run that block
    update_stage_file( { _run_once => { $full_label => 1 } } );

    return;
}

sub capture_imunify_features {
    -x IMUNIFY_AGENT or return;

    my $output   = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features list} );
    my @features = map { s/\s+//g; $_ } grep { m/\S/ } split( "\n", $output );

    if ( -f IMUNIFY_LICENSE_FILE ) {
        File::Copy::move( IMUNIFY_LICENSE_FILE, IMUNIFY_LICENSE_BACKUP );
    }

    update_stage_file( { 'reinstall' => { 'imunify_features' => \@features } } );

    return;
}

sub restore_imunify_features {

    return unless my $features = read_stage_file('reinstall')->{'imunify_features'};

    File::Copy::move( IMUNIFY_LICENSE_BACKUP, IMUNIFY_LICENSE_FILE ) if -f IMUNIFY_LICENSE_BACKUP;

    return unless ref $features eq 'ARRAY';
    return unless @$features;

    INFO("Restoring imunify 360 features.");
    foreach my $feature (@$features) {
        INFO("Restoring imunify360 $feature");
        my $log_file = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features install }, $feature );
        $log_file or next;
        chomp $log_file;
        next unless $log_file =~ m/\S/;

        monitor_imunify_feature_install( $feature, $log_file );
    }

    return;
}

sub imunify_feature_install_status ($feature) {
    my $install_status = eval {
        my $json = Cpanel::SafeRun::Simple::saferunnoerror( IMUNIFY_AGENT, qw{features status}, $feature, '--json' ) // '{}';
        Cpanel::JSON::Load($json);
    } // {};

    my $status = $install_status->{'items'}->{'status'} // '';

    return $status if $status =~ m/^(installed|installing|not_installed)$/i;
    return $install_status->{'items'}->{'message'} || "$feature is unknown";
}

# Wait 20 mins for the pid to finish.
sub monitor_imunify_feature_install ( $feature, $log_file ) {

    my $start = time;
    while ( time - $start < 30 ) {
        my $status = imunify_feature_install_status($feature);
        last if ( $status eq 'installed' || $status eq 'installing' && -e $log_file );
    }

    open( my $fh, '<', $log_file ) or do {
        my $status = imunify_feature_install_status($feature);
        WARN("Could not open $log_file for monitoring ($!). The install of $feature is in state: $status");
        return;
    };

    DEBUG("Monitoring $log_file for completion");

    # Tail the log file and monitor status of the install by making agent queries.
    $start = time;
    my $partial_line = '';
    while ( time - $start < 60 * 20 ) {    # abort after 20 minutes.

        # Tail the file for new information.
        while ( my $read = <$fh> ) {
            my $partial_line .= $read;
            if ( length $read && substr( $partial_line, -1, 1 ) eq "\n" ) {
                INFO($partial_line);
                $partial_line = '';
            }
        }

        # This takes 1.5 seconds to query every time.
        my $status = imunify_feature_install_status($feature);
        if ( $status eq 'installed' ) {
            INFO("Restore of $feature complete.");
            return 1;
        }
        if ( $status ne 'installing' ) {
            FATAL("Failed to install imunify 360 feature $feature ($status)");
            FATAL("See $log_file for more information");
            return 0;
        }

        sleep 5;
    }

    add_final_notification( "Imunify failed to install feature $feature", 1 );

    return 0;
}

sub _sanity_check {
    return 1 if -x $0;

    chmod 0700 => $0;

    return 1 if -x $0;

    ERROR("The script $0 is not executable, please fix it before running it again.");

    return;
}

sub print_box ($message) {

    INFO( "*" x 90 );
    INFO("*");
    INFO("* $message");
    INFO("*");
    INFO( "*" x 90 );

    return;
}

sub setup_outdated_services ($self) {

    my $content = '';

    if ( -e IGNORE_OUTDATED_SERVICES_FILE ) {
        $content = File::Slurper::read_binary(IGNORE_OUTDATED_SERVICES_FILE) // '';
    }

    my $service_name = $self->service->short_name;

    return if $content =~ qr{^${service_name}$}m;

    chomp($content);

    $content .= "\n" if length $content;
    $content .= $service_name . "\n";

    my $dirname = File::Basename::dirname(IGNORE_OUTDATED_SERVICES_FILE);
    if ( !-d $dirname ) {
        mkdir($dirname) or die qq[Fail to create directory $dirname - $!];
    }
    File::Slurper::write_binary( IGNORE_OUTDATED_SERVICES_FILE, $content );

    return 1;
}

sub restore_outdated_services ($self) {

    return unless -e IGNORE_OUTDATED_SERVICES_FILE;

    my $content = File::Slurper::read_binary(IGNORE_OUTDATED_SERVICES_FILE) // '';

    my $service_name = $self->service->short_name;

    if ( $content =~ s{^$service_name$}{}gm ) {
        1 while chomp $content;
        if ( $content =~ m{^\s*\z} ) {
            unlink IGNORE_OUTDATED_SERVICES_FILE;
            return 2;
        }
        else {
            $content .= "\n";
            File::Slurper::write_binary( IGNORE_OUTDATED_SERVICES_FILE, $content );
            return 1;
        }
    }

    return;
}

sub enable_all_cpanel_services ($self) {
    my $services = read_stage_file( 'disabled_cpanel_services', [] );
    unless (@$services) {
        WARN('No cPanel services were disabled!');
    }

    foreach my $service (@$services) {
        $self->ssystem( '/usr/bin/systemctl', 'enable', $service );
        $self->ssystem( '/usr/bin/systemctl', 'stop',   $service );
    }

    return;
}

sub stop_services_before_upcp ($self) {

    # make sure we stop some extra services before updating them

    $self->ssystem(qw{/scripts/restartsrv_tailwatchd --stop});
    $self->ssystem(qw{/scripts/restartsrv_dovecot    --stop});
    $self->ssystem(qw{/scripts/restartsrv_exim       --stop});

    return;
}

sub disable_all_cpanel_services ($self) {

    my @cpanel_services = qw/
      cpanel cpdavd cpgreylistd cphulkd cpipv6
      cpcleartaskqueue
      dnsadmin dovecot exim ipaliases mailman
      mysqld pdns proftpd queueprocd spamd
      crond tailwatchd
      lsws
      /;
    my @disabled_services;

    foreach my $name (@cpanel_services) {
        my $service = Elevate::SystemctlService->new( name => $name );

        next unless $service->is_enabled;
        $service->disable;

        push @disabled_services, $name;
    }
    update_stage_file( { 'disabled_cpanel_services' => [ sort @disabled_services ] } );

    return;
}

sub disable_known_yum_repositories {

    # remove all MySQL repos
    my @repo_files = map { Elevate::Constants::YUM_REPOS_D . '/' . $_ } Elevate::Blockers::Repositories::DISABLE_MYSQL_YUM_REPOS;

    foreach my $f (@repo_files) {
        next unless -e $f;
        if ( -l $f ) {
            unlink $f;
            next;
        }

        File::Copy::move( $f, "$f.off" ) or die qq[Fail to disable repo $f];
    }

    Cpanel::SafeRun::Simple::saferunnoerror(qw{/usr/bin/yum clean all});

    return;
}

sub _do_leapp_upgrade ($self) {

    INFO("Running leapp upgrade");

    my $ok = eval {
        local $ENV{LEAPP_OVL_SIZE} = 3000;
        $self->ssystem_and_die( { keep_env => 1 }, qw{/usr/bin/leapp upgrade} );
        1;
    };

    return 1 if $ok;

    my $msg = <<'EOS';
The 'leapp upgrade' process failed.

Please investigate, resolve then re-run the following command to continue the update:

    /scripts/elevate-cpanel --continue

EOS

    my $leapp_json_report = LEAPP_REPORT_JSON;
    if ( -e $leapp_json_report ) {
        my $report = eval { Cpanel::JSON::LoadFile($leapp_json_report) } // {};

        my $entries = $report->{entries};
        if ( ref $entries eq 'ARRAY' ) {
            foreach my $e (@$entries) {
                next unless ref $e && $e->{title} =~ qr{Missing.*answer}i;

                $msg .= $e->{summary} if $e->{summary};

                if ( ref $e->{detail} ) {
                    my $d = $e->{detail};

                    if ( ref $d->{remediations} ) {
                        foreach my $remed ( $d->{remediations}->@* ) {
                            next unless $remed->{type} && $remed->{type} eq 'command';
                            next unless ref $remed->{context};
                            my @hint = $remed->{context}->@*;
                            next unless scalar @hint;
                            $hint[0] = q[/usr/bin/leapp] if $hint[0] && $hint[0] eq 'leapp';
                            my $cmd = join( ' ', @hint );

                            $msg .= "\n\n";
                            $msg .= <<"EOS";
Consider running this command:

    $cmd
EOS
                        }
                    }

                }

            }
        }
    }

    if ( -e LEAPP_REPORT_TXT ) {
        $msg .= qq[\nYou can read the full leapp report at: ] . LEAPP_REPORT_TXT;
    }

    die qq[$msg\n];
}

# remove and store
sub pre_leapp_update_backup_and_cleanup ($self) {

    $self->run_once('capture_imunify_features');
    $self->run_component_once( 'EA4' => 'backup' );

    $self->run_once('backup_pecl_packages');
    $self->run_component_once( 'MySQL' => 'pre_leapp' );
    $self->run_once('cleanup_mysql_packages');
    $self->run_once('disable_known_yum_repositories');

    $self->run_once(
        arch_rpms => sub {

            # Backup arch rpms which we're going to remove and are provided by yum.
            my @installed_arch_cpanel_plugins;

            my $installed    = yum_list();
            my @cpanel_repos = grep { m/^cpanel-/ } keys %$installed;
            foreach my $repo (@cpanel_repos) {
                push @installed_arch_cpanel_plugins, map { $_->{'package'} } $installed->{$repo}->@*;
            }

            update_stage_file( { restore => { yum => \@installed_arch_cpanel_plugins } } ) if @installed_arch_cpanel_plugins;
            return;
        }
    );

    $self->purge_perl_xs(DISTRO_PERL_XS_PATH);
    $self->purge_perl_xs( $Config{'installsitearch'} );

    $self->run_once('remove_imunify_360');
    $self->run_once('remove_wordpress_toolkit');
    $self->run_once('capture_influxdb_state');
    $self->run_once('capture_jetbackup_state');
    $self->run_once('remove_nixstats');
    $self->run_once('pre_install_check_litespeed');

    return;
}

sub post_leapp_update_restore ($self) {

    INFO('Removing leapp from excludes in /etc/yum.conf');
    my $txt = eval { File::Slurper::read_text("/etc/yum.conf") };
    if ( length $txt ) {
        $txt =~ s/\s*python2-leapp,snactor,leapp-upgrade-el7toel8,leapp//ms;
        File::Slurper::write_text( "/etc/yum.conf", $txt );
    }

    # plugins can use MySQL - restore database earlier
    $self->run_component_once( 'MySQL' => 'post_leapp' );

    $self->run_once(
        'restore_perl_xs' => sub {
            restore_perl_xs(DISTRO_PERL_XS_PATH);
            restore_perl_xs( $Config{'installsitearch'} );

            return;
        }
    );

    $self->run_once(
        'restore_plugins' => sub {

            # Restore YUM arch plugins.
            my $stash            = read_stage_file();
            my $yum_arch_plugins = $stash->{'restore'}->{'yum'} // [];
            if (@$yum_arch_plugins) {
                INFO('Restoring cPanel yum-based-plugins');
                $self->ssystem( qw{ /usr/bin/dnf -y reinstall }, @$yum_arch_plugins );
            }

            return;
        }
    );

    $self->run_once('check_pecl_packages');
    $self->run_once('reinstall_imunify_360');
    $self->run_once('reinstall_wordpress_toolkit');
    $self->run_once('reinstall_influxdb');
    $self->run_once('reinstall_jetbackup');
    $self->run_once('kernel_check');
    $self->run_component_once( 'KernelCare' => 'post_leapp' );
    $self->run_once('restore_kernel_care');
    $self->run_once('restore_imunify_features');
    $self->run_once('restore_nixstats');
    $self->run_once('post_install_check_litespeed');
    $self->run_once('reinstall_digital_ocean_droplet_agent');

    return;
}

sub kernel_check ($self) {
    my @kernel_rpms = `/usr/bin/rpm -qa`;
    @kernel_rpms = sort grep { m/^kernel-\S+el7/ } @kernel_rpms;
    return unless @kernel_rpms;
    chomp @kernel_rpms;

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    my $msg = "The following kernels should probably be removed as they will not function on $pretty_distro_name:\n\n";
    foreach my $kernel (@kernel_rpms) {
        $msg .= "    $kernel\n";
    }

    $msg .= "\nYou can remove these by running: /usr/bin/rpm -e " . join( " ", @kernel_rpms ) . "\n";

    add_final_notification($msg);

    return;
}

sub backup_pecl_packages {
    my @ea_versions = qw{ea-php70 ea-php71 ea-php72 ea-php73 ea-php74 ea-php80};

    foreach my $v (@ea_versions) {
        _store_pecl_for( qq[/opt/cpanel/$v/root/usr/bin/pecl], $v );
    }

    _store_pecl_for( q[/usr/local/cpanel/3rdparty/bin/pecl], 'cpanel' );

    return;
}

sub check_pecl_packages {

    my $pecl = read_stage_file('pecl');

    return unless ref $pecl && scalar keys $pecl->%*;

    foreach my $v ( sort keys $pecl->%* ) {
        my $previously_installed = $pecl->{$v};

        return unless ref $previously_installed && scalar keys $previously_installed->%*;

        my $bin;
        if ( $v eq 'cpanel' ) {
            $bin = q[/usr/local/cpanel/3rdparty/bin/pecl];
        }
        else {
            $bin = qq[/opt/cpanel/$v/root/usr/bin/pecl];
        }

        my $currently_installed = _get_pecl_installed_for($bin) // {};

        my $final_notification;

        my $displayed_header = 0;
        foreach my $pkg ( sort keys $previously_installed->%* ) {
            next if $currently_installed->{$pkg};

            # for now do not check the version

            if ( !$displayed_header ) {
                $displayed_header = 1;
                WARN( q[*] x 20 );

                $final_notification = <<~"EOS";
                WARNING: Missing pecl package(s) for $bin
                Please reinstall these packages:
                EOS

                foreach my $l ( split( "\n", $final_notification ) ) {
                    next unless length $l;
                    WARN($l);
                }

                WARN( q[*] x 20 );
            }

            WARN("- $pkg");
            $final_notification .= qq[- $pkg\n];
        }

        add_final_notification($final_notification);

        WARN('#') if $displayed_header;
    }

    return;
}

sub _store_pecl_for ( $bin, $name ) {
    my $list = _get_pecl_installed_for($bin);

    remove_from_stage_file("pecl.$name");

    return unless ref $list && scalar keys $list->%*;

    update_stage_file( { pecl => { $name => $list } } );

    return;
}

sub _get_pecl_installed_for ($bin) {

    return unless -x $bin;

    my $out = Cpanel::SafeRun::Simple::saferunnoerror( $bin, 'list' ) // '';
    return if $?;

    my @lines = split( /\n/, $out );
    return unless scalar @lines >= 4;

    shift @lines for 1 .. 3;    # remove the header

    my $installed;

    foreach my $l (@lines) {
        my ( $package, $v, $state ) = split( /\s+/, $l, 3 );
        $installed->{$package} = $v;
    }

    return $installed;
}

sub clear_cpanel_caches ($self) {

    my @dirs = (

        # note: all cpanel users also have a '.cpanel/datastore'
        #       probably not necessary to cleanup
        '/root/.cpanel/datastore',    # cleanup root CachedCommand
    );

    my @files = qw{
      /var/cpanel/GetOS.cache
    };

    foreach my $d (@dirs) {
        $self->ssystem( qw{/usr/bin/rm -rf}, $d );
    }

    unlink $_ foreach @files;

    return;
}

sub _fetch_imunify_installer ($product) {

    $product =~ s/Plus/+/;
    my %installer_scripts = (
        'imunifyAV'  => 'https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh',
        'imunifyAV+' => 'https://repo.imunify360.cloudlinux.com/defence360/imav-deploy.sh',
        'imunify360' => 'https://www.repo.imunify360.cloudlinux.com/defence360/i360deploy.sh',
    );

    my $installer_url = $installer_scripts{$product} or do {
        ERROR("Unknown product type $product");
        return;
    };

    return Elevate::Fetch::script( $installer_url, 'imunify_installer' );
}

sub tmp_dir ($self) {
    return $self->{tmp} //= File::Temp->newdir();    # auto cleanup on destroy
}

my $yum_list_cache;

sub yum_list ( $invalidate_cache = 0 ) {
    return $yum_list_cache if !$invalidate_cache && $yum_list_cache;

    my @lines = split "\n", Cpanel::SafeRun::Errors::saferunnoerror(qw{/usr/bin/yum list installed});
    while ( my $line = shift @lines ) {
        last if $line && $line =~ m/^Installed Packages/;
    }

    my %repos;
    while ( my $line = shift @lines ) {
        chomp $line;
        my ( $package, $version, $repo ) = split( qr{\s+}, $line );

        if ( !length $version ) {
            my $extra_line = shift @lines;
            chomp $extra_line;
            $extra_line =~ s/^\s+//;
            ( $version, $repo ) = split( ' ', $extra_line );
        }
        if ( !length $repo ) {
            $repo = shift @lines;
            chomp $repo;
            $repo =~ s/\s+//g;
        }
        length $repo or next;    # We screwed up the parse. move on.

        $repo =~ s/^\@// or next;
        $repos{$repo} ||= [];
        next if $repo eq 'installed';    # Not installed from a repo.

        $package =~ s/\.(noarch|x86_64)$//;
        my $arch = $1 // '?';
        push $repos{$repo}->@*, { 'package' => $package, 'version' => $version, arch => $arch };
    }

    return $yum_list_cache = \%repos;
}

sub get_installed_rpms_in_repo (@repo_list) {

    my @to_remove;
    my $installed = yum_list();

    # Regex for repos.
    if ( ref $repo_list[0] eq 'Regexp' ) {
        scalar @repo_list == 1 or Carp::confess("too many args");
        my $regex = shift @repo_list;

        @repo_list = grep { $_ =~ $regex } keys %$installed;
    }

    foreach my $repo (@repo_list) {
        next unless ref $installed->{$repo};
        next unless scalar $installed->{$repo}->@*;
        push @to_remove, map { $_->{'package'} } $installed->{$repo}->@*;
    }

    return @to_remove;
}

sub remove_rpms_from_repos ( $self, @repo_list ) {

    die qq[remove_rpms_from_repos: Not a method call - $self, @repo_list] unless ref $self;

    my @to_remove = get_installed_rpms_in_repo(@repo_list);

    return unless @to_remove;

    INFO( "Removing packages for " . join( ", ", @repo_list ) );

    __PACKAGE__->ssystem( qw{/usr/bin/yum -y erase}, @to_remove );

    return;
}

sub backup_3rdparty_file ($file) {
    my $target = "$file.elevate_backup";
    return File::Copy::copy( $file, $target );
}

sub capture_jetbackup_state {
    remove_from_stage_file('reinstall.jetbackup');

    return unless Cpanel::Pkgr::is_installed('jetbackup5-cpanel');

    my $repos = yum_list();
    my $jetbackup_tier =
        $repos->{'jetapps-stable'} ? 'jetapps-stable'
      : $repos->{'jetapps-edge'}   ? 'jetapps-edge'
      : $repos->{'jetapps-beta'}   ? 'jetapps-beta'
      :                              'jetapps-stable';    # Just give up and choose stable if you can't guess.
    INFO("Jetbackup tier '$jetbackup_tier' detected. Not removing jetbackup. Will re-install it after elevate.");
    my @reinstall = get_installed_rpms_in_repo(qw/jetapps jetapps-stable jetapps-beta jetapps-edge/);
    unshift @reinstall, $jetbackup_tier;

    my $data = {
        tier     => $jetbackup_tier,
        packages => \@reinstall,
    };

    update_stage_file( { 'reinstall' => { 'jetbackup' => $data } } );

    return;
}

sub reinstall_jetbackup ($self) {
    my $data = read_stage_file('reinstall')->{'jetbackup'};
    return unless ref $data && ref $data->{packages};

    INFO("Re-installing jetbackup.");

    my $tier     = $data->{tier};
    my @packages = $data->{packages}->@*;
    $self->ssystem( qw{/usr/bin/yum -y reinstall  --disablerepo=* --enablerepo=jetapps}, "--enablerepo=$tier", @packages );

    return;
}

sub capture_influxdb_state {
    remove_from_stage_file('reinstall.influxdb');

    return unless Cpanel::Pkgr::is_installed('telegraf');
    INFO("Not removing influxdb. Will re-install it after elevate.");
    update_stage_file( { 'reinstall' => { 'influxdb' => 1 } } );

    return;
}

sub reinstall_influxdb ($self) {
    return unless read_stage_file('reinstall')->{'influxdb'};
    INFO("Re-installing telegraf for influxdb");
    $self->ssystem_and_die(qw{/usr/bin/yum -y reinstall telegraf});

    return;
}

sub has_nixstats {
    return -e q[/etc/systemd/system/nixstatsagent.service] || -e q[/usr/local/bin/nixstatsagent];
}

sub remove_nixstats ($self) {

    return unless has_nixstats();

    INFO("Removing nixstats");

    my $backup_dir = ELEVATE_BACKUP_DIR . "/nixstats";

    File::Path::make_path($backup_dir);
    die "Fail to create backup directory: $backup_dir" unless -d $backup_dir;

    my @to_backup = qw{ /etc/nixstats-token.ini /etc/nixstats.ini };

    # files we need to restore later
    my $to_restore = {};

    foreach my $f (@to_backup) {
        next unless -f $f;
        my $name   = File::Basename::basename($f);
        my $backup = "$backup_dir/$name";
        File::Copy::move( $f, $backup );

        $to_restore->{$backup} = $f;
    }

    my $service_name = q[nixstatsagent];
    my $service      = Elevate::SystemctlService->new( name => $service_name );

    my $is_enabled = $service->is_enabled;

    $service->disable if $is_enabled;
    $service->stop;

    my $pip;

    if ( -x q[/usr/bin/pip3] ) {
        $pip = q[/usr/bin/pip3];
    }
    elsif ( -x q[/usr/bin/pip] ) {
        $pip = q[/usr/bin/pip];
    }

    if ($pip) {
        $self->ssystem( $pip, qw{uninstall -y nixstatsagent} );
    }
    else {
        ERROR("Cannot remove nixstatsagent: cannot find pip binary");
    }

    my $data = {
        service_enabled => $is_enabled,
        to_restore      => $to_restore,
    };

    update_stage_file( { 'reinstall' => { 'nixstats' => $data } } );

    return;
}

sub restore_nixstats ($self) {
    my $data = read_stage_file('reinstall')->{'nixstats'};
    return unless ref $data;

    INFO("Restoring nixstats");

    # we reinstall nixstats using a non existing user id
    #   this avoid adding some polution to their account
    #   by creating a server we are then going to replace just after
    # alternatively we could use the user from the nixstats-token.ini file
    my $user = q[deadbeefdeadbeefdeadbeef];

    my $installer_script = Elevate::Fetch::script( 'https://www.nixstats.com/nixstatsagent.sh', 'nixstatsagent' );

    $self->ssystem( '/usr/bin/bash', $installer_script, $user );

    unlink $installer_script;

    if ( !-x q[/usr/local/bin/nixstatsagent] ) {
        ERROR("Missing nixstatsagent binary: /usr/local/bin/nixstatsagent");
    }

    my $service = q[nixstatsagent];

    # Stopping the agent
    $self->ssystem( qw{/usr/bin/systemctl stop}, $service );

    # Restoring backup files
    my $to_restore = $data->{to_restore};

    foreach my $src ( sort keys %$to_restore ) {
        my $destination = $to_restore->{$src};

        File::Copy::copy( $src, $destination );
    }

    # restoring the state of the service before elevation
    if ( $data->{service_enabled} ) {
        $self->ssystem( qw{/usr/bin/systemctl enable}, $service );
    }
    else {    # leave it disabled
        $self->ssystem( qw{/usr/bin/systemctl disable}, $service );
    }

    # do not really need to start/stop the daemon, we are about to reboot
    #   but start it for sanity purpose

    $self->ssystem( qw{/usr/bin/systemctl start}, $service );
    if ( $? == 0 ) {
        INFO("nixstatsagent restored");
    }
    else {
        add_final_notification( "Failed to start nixstatsagent.service", 1 );
    }

    return;
}

sub remove_wordpress_toolkit ($self) {
    return unless Cpanel::Pkgr::is_installed('wp-toolkit-cpanel');

    INFO("Removing Wordpress Toolkit");

    INFO("Removing the rpm wp-toolkit-cpanel (--noscripts)");
    backup_3rdparty_file('/usr/local/cpanel/3rdparty/wp-toolkit/var/wp-toolkit.sqlite3');
    backup_3rdparty_file('/usr/local/cpanel/3rdparty/wp-toolkit/var/etc/.shadow');
    my ($output) = Cpanel::SafeRun::Errors::saferunallerrors(qw{/usr/bin/rpm -e --noscripts wp-toolkit-cpanel});
    DEBUG($output) if $output;

    yum_list(1);    # Invalidate the cache since we just ran an rpm -e by hand.
    $self->remove_rpms_from_repos(qw/wp-toolkit-cpanel wp-toolkit-thirdparties/);

    update_stage_file( { 'reinstall' => { 'wordpress_toolkit' => 1 } } );

    return;
}

sub reinstall_wordpress_toolkit ($self) {
    return unless read_stage_file('reinstall')->{'wordpress_toolkit'};

    INFO("Restoring Wordpress Toolkit");
    my $installer_script = Elevate::Fetch::script( 'https://wp-toolkit.plesk.com/cPanel/installer.sh', 'wptk_installer' );

    $self->ssystem( '/usr/bin/bash', $installer_script );
    unlink $installer_script;

    return;
}

sub pre_install_check_litespeed ($self) {

    remove_from_stage_file('reinstall.litespeed');

    my $ls_cfg_dir = q[/usr/local/lsws/conf];
    return unless -d $ls_cfg_dir;

    INFO("LiteSpeed is installed");

    # check if the license is valid before updating
    $self->ssystem(qw{/usr/local/lsws/bin/lshttpd -V});
    my $has_valid_license = $? == 0 ? 1 : 0;

    my $data = {
        has_valid_license => $has_valid_license,
    };

    update_stage_file( { 'reinstall' => { 'litespeed' => $data } } );

    return;
}

sub post_install_check_litespeed ($self) {
    my $data = read_stage_file('reinstall')->{'litespeed'};
    return unless ref $data;

    INFO("Checking LiteSpeed");

    # check the current license
    if ( $data->{has_valid_license} ) {
        $self->ssystem(qw{/usr/local/lsws/bin/lshttpd -V});
        ERROR("LiteSpeed license is not valid. Check /usr/local/lsws/conf/serial.no") if $? != 0;
    }

    $self->ssystem(qw{/usr/bin/systemctl restart lsws});

    return;
}

sub reinstall_digital_ocean_droplet_agent ($self) {
    return unless Cpanel::Pkgr::is_installed('droplet-agent');
    return unless -f '/etc/yum.repos.d/droplet-agent.repo';

    $self->ssystem(qw{/usr/bin/yum -y reinstall droplet-agent});

    return;
}

sub remove_imunify_360 ($self) {

    # One of these 2 rpms should be in place or imunify isn't really functioning.
    my $im360 = Cpanel::Pkgr::is_installed('imunify360-firewall');
    my $imav  = Cpanel::Pkgr::is_installed('imunify-antivirus');
    return unless $im360 || $imav;

    my $agent_bin = IMUNIFY_AGENT;
    return unless -x $agent_bin;
    my $license_data = eval { Cpanel::JSON::Load(`$agent_bin version --json 2>&1`) } // {};
    return unless $license_data->{'license'}->{'status'};    # Must be true.

    my $product_type = $license_data->{'license'}->{'license_type'};

    INFO("Removing $product_type prior to upgrade.");

    update_stage_file( { 'reinstall' => { 'imunify' => $product_type } } );
    INFO("Product $product_type detected. Uninstalling before upgrade for later restore");

    my $installer_script = _fetch_imunify_installer($product_type) or return;

    $self->ssystem( '/usr/bin/bash', $installer_script, '--uninstall' );
    unlink $installer_script;

    # Cleanup any lingering packages.
    $self->remove_rpms_from_repos('imunify');

    return;
}

sub reinstall_imunify_360 ($self) {
    my $product_type = read_stage_file('reinstall')->{'imunify'} or return;

    my $installer_script = _fetch_imunify_installer($product_type) or return;

    $self->ssystem( '/usr/bin/bash', $installer_script );
    unlink $installer_script;

    return;
}

sub post_upgrade_check ($self) {

    my $expect_distro = $self->upgrade_to_rocky() ? 'rocky' : 'almalinux';

    unless ( Cpanel::OS::major() == 8 && Cpanel::OS::distro() eq $expect_distro ) {
        my $pretty_distro_name = $self->upgrade_to_pretty_name();
        FATAL("Your distro does not looks like $pretty_distro_name.");
        return 1;
    }

    # call a cpanel binary
    $self->ssystem_and_die(qw{/usr/local/cpanel/cpanel -V});

    return 0;
}

sub purge_perl_xs ( $self, $path ) {

    return unless length $path && -d $path;

    my @perl_modules;

    File::Find::find(
        sub {
            return unless substr( $_, -3 ) eq '.pm';
            return if -l $_;
            return unless -f $_;

            push @perl_modules, $File::Find::name;

        },
        $path
    );

    my $path_len = length($path);
    @perl_modules = map { substr( $_, $path_len + 1 ) } sort { $a cmp $b } @perl_modules;

    my $xspm_to_rpm = xspm_to_rpm();

    my %rpms_to_restore;
    my @modules_to_restore;
    foreach my $file (@perl_modules) {

        # We can only convert distro perl arch perl modules to RPM.
        if ( $path eq DISTRO_PERL_XS_PATH && length $xspm_to_rpm->{$file} ) {
            $rpms_to_restore{$file} = $xspm_to_rpm->{$file};
        }
        else {
            push @modules_to_restore, $file;
        }
    }

    my $pretty_distro_name = $self->upgrade_to_pretty_name();

    my $stash = {};
    if (%rpms_to_restore) {
        INFO("The following `cpan` installed perl Modules will be removed and replaced with a $pretty_distro_name RPM after upgrade:");
        foreach my $file ( sort { $rpms_to_restore{$a} cmp $rpms_to_restore{$b} || $a cmp $b } keys %rpms_to_restore ) {
            INFO( sprintf( "  %20s => %s", $file, $rpms_to_restore{$file} ) );

            my $files_in_rpm = $stash->{'restore'}->{$path}->{'rpm'}->{ $rpms_to_restore{$file} } //= [];
            unless ( grep { $_ eq $file } @$files_in_rpm ) {    # Only if we've not stored this.
                push @$files_in_rpm, $file;
                unlink "$path/$file";
            }
        }
        INFO(' ');
    }

    if (@modules_to_restore) {
        WARN("The following modules will likely not be functional on $pretty_distro_name and will be disabled. You will need to restore these manually:");
        my $to_restore = $stash->{'restore'}->{$path}->{'cpan'} //= [];
        foreach my $file (@modules_to_restore) {
            WARN("    $path/$file");
            next if grep { $_ eq $file } @$to_restore;    # We've already stashed this.
            push @$to_restore, $file;
            rename "$path/$file", "$path/$file.o";
        }
    }

    update_stage_file($stash);

    return;
}

sub restore_perl_xs ($path) {
    my $stash = read_stage_file();

    if ( $path eq DISTRO_PERL_XS_PATH ) {
        my $rpms = $stash->{'restore'}->{ DISTRO_PERL_XS_PATH() }->{'rpm'};

        if ( scalar keys %$rpms ) {    # If there are no XS modules to replace, there is no point to running the dnf install:
            my @cmd = ( '/usr/bin/dnf', '-y', '--enablerepo=epel', '--enablerepo=powertools', 'install', sort keys %$rpms );
            __PACKAGE__->ssystem(@cmd);
        }
    }

    my $cpan_modules = $stash->{$path}->{'cpan'} // return;

    # TODO: Let's restore this with /usr/bin/cpan!
    my $msg = "The following XS modules will need to be re-installed:\n\n";
    foreach my $module (@$cpan_modules) {
        $msg .= "   $module\n";
    }
    add_final_notification($msg);

    return;
}

sub xspm_to_rpm () {
    return {
        'IO/Pty.pm'           => 'perl-IO-Tty',
        'IO/Tty.pm'           => 'perl-IO-Tty',
        'IO/Tty/Constant.pm'  => 'perl-IO-Tty',
        'JSON/Syck.pm'        => 'perl-YAML-Syck',
        'JSON/XS.pm'          => 'perl-JSON-XS',
        'JSON/XS/Boolean.pm'  => 'perl-JSON-XS',
        'YAML/Dumper/Syck.pm' => 'perl-YAML-Syck',
        'YAML/Loader/Syck.pm' => 'perl-YAML-Syck',
        'YAML/Syck.pm'        => 'perl-YAML-Syck',
        'common/sense.pm'     => 'perl-common-sense',
        'version.pm'          => 'perl-version',
        'version/regex.pm'    => 'perl-version',
        'version/vpp.pm'      => 'perl-version',
        'version/vxs.pm'      => 'perl-version',
    };
}

sub setup_answer_file {
    my $leapp_dir = '/var/log/leapp';

    mkdir $leapp_dir unless -d $leapp_dir;

    my $leapp_answers = $leapp_dir . '/answerfile.userchoices';

    if ( -f $leapp_answers && -s _ ) {
        warn "Preserve leap answers file: ", $leapp_answers;
        return;
    }

    open( my $fh, '>', $leapp_answers ) or die qq[Fail to setup leapp anserfile.userchoices: $!];
    print {$fh} <<~'EOF';
        [remove_pam_pkcs11_module_check]
        confirm = True
        EOF
    close $fh;

    return;
}

# TODO: We're going to need to store reboot time so we know if the last reboot has happened when we re-run the script.

sub read_stage_file ( $k = undef, $default = {} ) {
    my $stage_info = _read_stage_file() // {};

    return $stage_info->{$k} // $default if defined $k;
    return $stage_info;
}

sub _read_stage_file {    # can be mocked during unit tests
    return eval { Cpanel::JSON::LoadFile(ELEVATE_STAGE_FILE) };
}

sub save_stage_file ($stash) {
    open( my $fh, '>', ELEVATE_STAGE_FILE ) or LOGDIE( "Fail to open " . ELEVATE_STAGE_FILE . ": $!" );
    print {$fh} Cpanel::JSON::pretty_canonical_dump($stash);
    close $fh;

    return 1;
}

sub update_stage_file ($data) {

    die q[Need a hash] unless ref $data eq 'HASH';

    my $current = read_stage_file();
    my $merged  = Hash::Merge::merge( $data, $current );

    return save_stage_file($merged);
}

sub remove_from_stage_file ($key) {
    return unless length $key;

    my $stage = read_stage_file();

    my @list = split( qr/\./, $key );
    return unless scalar @list;

    my $to_delete = pop @list;

    my $h = $stage;
    while ( my $k = shift @list ) {
        $h = $h->{$k};
        last unless ref $h;
    }

    return if scalar @list;
    return unless exists $h->{$to_delete};

    delete $h->{$to_delete};

    return save_stage_file($stage);
}

sub get_stage {
    return read_stage_file( 'stage_number', 0 );
}

sub bump_stage ( $self, $by = 1 ) {

    return _update_stage_number( get_stage() + $by );
}

sub _update_stage_number ($stage_id) {

    if ( $stage_id > 10 ) {    # protection for stage
        require Carp;
        Carp::confess("Invalid stage number $stage_id");
    }

    update_stage_file( { stage_number => $stage_id } );

    return $stage_id;
}

sub reboot ($self) {
    $self->bump_stage();

    # protection
    my $stage = get_stage();

    if ( $stage > VALID_STAGES + 1 ) {
        LOGDIE(qq[Cannot reboot reaching stage $stage]);
    }
    elsif ( $stage <= VALID_STAGES ) {
        print_box( "Rebooting into stage $stage of " . VALID_STAGES );
    }
    else {
        print_box("Doing final reboot");
    }

    if ( request_manual_reboots() ) {
        WARN("Manual Reboot Mode Enabled: please reboot the server to move to the next stage $stage");
        return 0;
    }

    sleep(2);    # ensure display is flushed (using tail...)

    my $exit = $self->ssystem( '/usr/sbin/reboot', 'now' ) or return 0;
    LOGDIE("Failed to reboot system please correct this and reboot");
}

sub request_manual_reboots() {
    return !!read_stage_file( 'manual_reboots', 0 );
}

sub read_redhat_release() {
    my ($first_line) = split( "\n", Cpanel::LoadFile::loadfile('/etc/redhat-release') // '' );

    return $first_line;
}

1;
