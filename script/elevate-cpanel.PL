#!/usr/local/cpanel/3rdparty/bin/perl

# Copyright 2024 WebPros International, LLC
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

Wrapper around the ELevate project which is designed to enable migrations
between major versions of RHEL® derivatives.

Currently supported upgrade paths:

CentOS 7     => AlmaLinux 8
CloudLinux 7 => CloudLinux 8

=head1 SYNOPSIS

    /scripts/elevate-cpanel [OPTIONS]

    Optional:
       --start                                   Start the conversion process.
       --continue                                Continue the conversion: retry the last step.
       --check[=BLOCKER_FILE]                    Check if your system has any known blockers to upgrade.
       --log                                     Show the current elevation log.
       --status                                  Check the current elevation status.
       --clean                                   Cleanup scripts and files created by elevate-cpanel.
       --leappbeta                               Use the special beta repo from leapp. Do this only if instructed to by cPanel.
       --non-interactive                         Skip the yes/no prompt before proceeding with the upgrade.

       --update                                  Instruct the script to replace itself on disk with a downloaded copy of the latest version.
       --version                                 Print the version number and exit.

       --skip-elevate-version-check              Skip the check for whether this script is up to date.
       --skip-cpanel-version-check               Skip the check for whether cPanel is up to date.
                                                 This option is intended only for testing!

       --upgrade-distro-manually
       --no-leapp                                Do not try to run the distro upgrade process, and pause instead.
                                                 Once the upgrade has been run you should remove the file
                                                 /waiting_for_distro_upgrade

       --help                                    Display this documentation.

=head1 COMMON USAGE

=over

=item Start an installation

You can start an elevation update by running:

    /scripts/elevate-cpanel --start

=item Start an installation and skip the confirmation prompt

By default, you will be asked if you wish to proceed with the upgrade.
If you wish to skip this prompt (by assuming yes):

    # Perform the update in non-interactive mode
    /scripts/elevate-cpanel --start --non-interactive

=item Compatibility check with elevation

You can check if your server is compatible with the upgrade process without
starting an upgrade process.

    /scripts/elevate-cpanel --check

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

=head2 Advanced Options

=head3 Using an alternative tool to upgrade your distro

By default, the elevate script runs the L<leapp process|https://almalinux.org/elevate/>
to upgrade you from 7 to 8. `Leapp` may not be compatible with your system.

Using the `--upgrade-distro-manually` option gives you a way to do the actual distro upgrade in your own way.
This, for instance, can be used to allow `Virtuozzo` systems to upgrade cPanel systems, which are not supported by `Leapp`.

A `--upgrade-distro-manually` upgrade would look like:

=over

=item 1. User runs `/scripts/elevate-cpanel --start --upgrade-distro-manually` which starts the upgrade process.

=item 2. `elevate-cpanel` does all preparatory steps to upgrade the system prior to the distro upgrade.

=item 3. Elevate will then create the file `/waiting_for_distro_upgrade` to indicate that the operating system is ready for an upgrade.

=over

=item * This is when you would use your distro upgrade tool.

=item * When you have completed upgrading your system, simply remove `/waiting_for_distro_upgrade` and reboot the system into normal multi-user mode.

=back

=item 4. Elevate will resume upon reboot and complete the upgrade just like it would have without `--upgrade-distro-manually`

=back

NOTE: `--upgrade-distro-manually` is not required for helper commands like `--continue` or `--status`

=head1 WARNINGS

The elevation process to perform a major OS upgrade is not a risk free update.
Depending on the state of your current distribution multiple errors can occur.
We recommend updating your system to the last upstream state before starting.

It is *highly* recommended that you have a full backup or snapshot
of your server before beginning the elevation process.

The elevation process can take several long minutes and requires multiple reboots.
Some reboots are expected to be longer than normal.

Please do not interrupt the reboots and elevation process.

=head1 SEE ALSO

    Read more from https://cpanel.github.io/elevate/

=cut

use cPstrict;

use Elevate::Constants ();

BEGIN {
    # sanity check before loading the script
    eval { require Cpanel::Version::Tiny } or do {
        warn(qq[This script is designed to only run on cPanel servers.\n]);
        exit 1;    ## no critic(Cpanel::NoExitsFromSubroutines)
    };

    $ENV{LANG}        = "C";
    $ENV{LANGUAGE}    = "C";
    $ENV{LC_ALL}      = "C";
    $ENV{LC_MESSAGES} = "C";
    $ENV{LC_CTYPE}    = "C";
}

use Log::Log4perl qw(:easy);

use Config;
use Carp                  ();
use Errno                 ();
use File::Copy            ();
use File::Copy::Recursive ();
use File::Find            ();
use File::Path            ();
use File::Slurper         ();
use File::Spec            ();
use Hash::Merge           ();
use IO::Prompt            ();
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

# - fatpack Components
use Elevate::Components::Base               ();
use Elevate::Components                     ();
use Elevate::Components::AbsoluteSymlinks   ();
use Elevate::Components::AutoSSL            ();
use Elevate::Components::BootKernel         ();
use Elevate::Components::CCS                ();
use Elevate::Components::CloudLinux         ();
use Elevate::Components::cPanelPlugins      ();
use Elevate::Components::cPanelPrep         ();
use Elevate::Components::DatabaseUpgrade    ();
use Elevate::Components::DiskSpace          ();
use Elevate::Components::Distros            ();
use Elevate::Components::DNS                ();
use Elevate::Components::EA4                ();
use Elevate::Components::ElevateScript      ();
use Elevate::Components::ELS                ();
use Elevate::Components::Grub2              ();
use Elevate::Components::Imunify            ();
use Elevate::Components::InfluxDB           ();
use Elevate::Components::IsContainer        ();
use Elevate::Components::JetBackup          ();
use Elevate::Components::KernelCare         ();
use Elevate::Components::Kernel             ();
use Elevate::Components::Leapp              ();
use Elevate::Components::LiteSpeed          ();
use Elevate::Components::MountPoints        ();
use Elevate::Components::MySQL              ();
use Elevate::Components::NICs               ();
use Elevate::Components::NixStats           ();
use Elevate::Components::OVH                ();
use Elevate::Components::PackageRestore     ();
use Elevate::Components::Panopta            ();
use Elevate::Components::PECL               ();
use Elevate::Components::PerlXS             ();
use Elevate::Components::PostgreSQL         ();
use Elevate::Components::R1Soft             ();
use Elevate::Components::Repositories       ();
use Elevate::Components::RmMod              ();
use Elevate::Components::RpmDB              ();
use Elevate::Components::SSH                ();
use Elevate::Components::UnconvertedModules ();
use Elevate::Components::WHM                ();
use Elevate::Components::WPToolkit          ();
use Elevate::Components::Acronis            ();

# - fatpack OS
use Elevate::OS              ();
use Elevate::OS::CentOS7     ();
use Elevate::OS::CloudLinux7 ();
use Elevate::OS::RHEL        ();

use Elevate::Database         ();
use Elevate::EA4              ();
use Elevate::Fetch            ();
use Elevate::Leapp            ();
use Elevate::Logger           ();
use Elevate::Marker           ();
use Elevate::Motd             ();
use Elevate::NICs             ();
use Elevate::Notify           ();
use Elevate::Roles::Run       ();    # used as parent, but ensure fatpack
use Elevate::RPM              ();
use Elevate::Script           ();
use Elevate::Service          ();
use Elevate::StageFile        ();
use Elevate::Stages           ();
use Elevate::SystemctlService ();
use Elevate::Usage            ();
use Elevate::DNF              ();
use Elevate::YUM              ();

#<<V *** DO NOT EDIT THESE LINES MANUALLY ***
use constant VERSION => 1;
#>>V *** DO NOT EDIT THESE LINES MANUALLY ***

use constant VALID_STAGES => 5;

use constant NOC_RECOMMENDATIONS_TOUCH_FILE => q[/var/cpanel/elevate-noc-recommendations];

# XXX TODO verify that imunify reponames are in fact correct.
# As of now they are straight up guesses.

use constant ACTION_REBOOT_NEEDED   => 4242;    # just one unique id
use constant ACTION_PAUSE_REQUESTED => 4243;
use constant ACTION_CONTINUE        => 4244;

use constant PAUSE_ELEVATE_TOUCHFILE => q[/waiting_for_distro_upgrade];

use Simple::Accessor qw{
  service
  script
  components
  leapp
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

sub _build_components ($self) {

    # FIXME weaken
    return Elevate::Components->new( cpev => $self );
}

sub _build_leapp ($self) {

    # FIXME weaken
    return Elevate::Leapp->new( cpev => $self );
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

    if ( $self->getopt('start') ) {
        die qq[Unsupported option with --start\n]        if $self->getopt('continue') || $self->getopt('service');
        die qq[BETA is unavailable for this leapp repo.] if $self->getopt('leappbeta') && !length Elevate::OS::leapp_repo_beta();

        return 1 if $self->start();
    }
    elsif ( $self->getopt('status') ) {
        return $self->check_status();
    }

    return $self->do_cleanup()        if $self->getopt('clean');
    return $self->components->check() if defined $self->getopt('check');

    my $stage = Elevate::Stages::get_stage();

    if ( $stage == 0 ) {
        print_box_no_log( <<~EOS );
        Please re-run this script with

            --help  to know more about this script
            --check to check if your server is ready to upgrade
            --start if you would like to begin the upgrade process

            Read more from https://cpanel.github.io/elevate/

        EOS
        return 0;
    }

    if ( $self->getopt('start') || $self->getopt('log') ) {
        1;    # these options are exclusive
    }
    elsif ( $self->getopt('continue') ) {
        $self->continue_elevation();
    }
    elsif ( $self->getopt('service') ) {

        # running from the systemct service
        return $self->run_service_and_notify();
    }

    $self->monitor_upgrade();

    return 0;
}

sub get_component ( $self, $name ) {
    my $pkg = qq[Elevate::Components::$name];

    # my $sub = $pkg->can( 'new' ) or die qq[Missing new from $pkg];
    # my $x = $sub->( $pkg, cpev => $self );
    # return $x;
    return $pkg->new( components => $self->components );
}

sub get_blocker ( $self, $name ) {    # helper for tests
    return $self->components->_get_blocker_for($name);
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

sub monitor_upgrade ($self) {
    my $stage = Elevate::Stages::get_stage();

    my $tail_msg = q[Running: tail -f ] . Elevate::Constants::LOG_FILE;

    my $status = $self->get_current_status();

    if ( $status eq 'success' ) {
        Elevate::Logger::INFO_nolog("# Upgrade was successful. Showing the last lines of the update log.");
    }
    elsif ( $status eq 'running' || $status eq 'paused' ) {
        Elevate::Logger::INFO_nolog("# Monitoring existing $status upgrade (stage=$stage) ; $tail_msg");
    }
    elsif ( $status eq 'failed' ) {
        Elevate::Logger::ERROR_nolog("# Upgrade process failed at stage=$stage ; $tail_msg");
    }
    else {
        Elevate::Logger::WARN_nolog("# Monitoring upgrade file (stage=$stage) ; $tail_msg");
    }

    exec( qw{/usr/bin/tail -n40 -F }, Elevate::Constants::LOG_FILE );
}

sub start ($self) {

    return 1 unless _sanity_check();

    my $stage = Elevate::Stages::get_stage();
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
            /scripts/elevate-cpanel --status
        EOS

    }

    # Check for blockers before starting the migration
    return 1 if ( $self->components->check() );

    $self->give_last_chance();

    system touch => Elevate::Constants::LOG_FILE;

    # store the manual reboots flag
    if ( $self->getopt('manual-reboots') ) {
        WARN('Manual Reboot would be required between each stages');
        Elevate::StageFile::update_stage_file( { manual_reboots => 1 } );
    }

    $self->_capture_env_variables();    # capture at startup

    if ( $self->getopt('upgrade-distro-manually') || $self->getopt('no-leapp') ) {
        my $touchfile = PAUSE_ELEVATE_TOUCHFILE;
        WARN( <<~"EOS");
        Automated upgrade of the distro has been disabled.
        Please wait for the file '$touchfile' to be created.
        At that stage, the ELevate process is paused, and you can upgrade from 7 to 8 on your own.

        Once the system has been successfully upgraded from 7 to 8, you can then remove that file
        to let the ELevate process continue and update cPanel for the new distribution.
        EOS
        Elevate::StageFile::update_stage_file( { upgrade_distro_manually => 1 } );
    }

    # This starts the service for us:
    return $self->service->install();
}

sub _capture_env_variables ($self) {

    if ( my $ovl_size = $ENV{LEAPP_OVL_SIZE} ) {
        Elevate::StageFile::update_stage_file( { env => { LEAPP_OVL_SIZE => $ovl_size } } );
    }

    return;
}

# This code used to be in stage 1, but it makes more sense for it to take place before a stage has been set.
sub give_last_chance ($self) {

    my $upgrade_from_name  = Elevate::OS::pretty_name();
    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    print_box(qq[/!\ Warning: You are about to convert your cPanel & WHM $upgrade_from_name to $pretty_distro_name server.]);

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
It is *highly* recommended that you have a full backup or snapshot
of your server before proceeding.
EOS

    if ( !$self->getopt('non-interactive') ) {
        if (
            !IO::Prompt::prompt(
                '-one_char',
                '-yes_no',
                '-tty',
                -default => 'n',
                "Do you wish to proceed with the upgrade process [y/N]: ",
            )
        ) {
            INFO("The update process has been canceled");
            exit 0;    ## no critic qw(Cpanel::NoExitsFromSubroutines)
        }
    }

    INFO("The update process has begun");

    return;
}

sub continue_elevation ($self) {

    my $status = $self->get_current_status();
    if ( $status eq 'success' ) {
        Elevate::Logger::INFO_nolog("Elevate process was successful. No process to continue.");
        return;
    }

    if ( $self->service->is_active ) {
        Elevate::Logger::WARN_nolog( "The service " . $self->service->name . " is still running. Please wait for it to finish before restarting it." );
        return;
    }

    # check that no process is running and remove the pidfile for the other
    $self->check_and_create_pidfile()->remove_pid_file;

    my $stage = Elevate::Stages::get_stage();
    if ( $stage == 0 ) {
        Elevate::Logger::ERROR_nolog("Looks like no elevate process was started. Please consider running: /scripts/elevate-cpanel --start");
        return;
    }

    $self->_capture_env_variables();    # capture env before restart

    my $pid = fork();
    LOGDIE(qq[Failed to fork: $!]) unless defined $pid;
    if ($pid) {
        Elevate::Logger::INFO_nolog("Restarting install process (stage=$stage)");
        return 1;
    }
    else {
        # when restarting leapp process the restart process can hang for a long time
        #   return earlier to let the user tail the service log
        $self->service->restart;
        exit(0);
    }
}

sub do_cleanup ( $self, $handle_service_manually = 0 ) {

    if ( !$handle_service_manually ) {
        $self->service->remove;
        $self->ssystem( '/usr/bin/systemctl', 'daemon-reload' );
    }

    Elevate::StageFile::remove_stage_file();
    unlink Elevate::Constants::PID_FILE;

    unlink Elevate::Constants::OVH_MONITORING_TOUCH_FILE;

    Elevate::Motd->cleanup();

    return 0;
}

sub run_service_and_notify ($self) {    # FIXME: move to Elevate::Service - need Notify

    # check it outside the eval block to avoid notification from the command line
    $self->check_and_create_pidfile();

    my $stage = Elevate::Stages::get_stage();

    if ( $stage >= 2 ) {
        my $status = $self->get_current_status();
        Elevate::StageFile::update_stage_file( { status => q[running] } ) if $status ne 'paused';
    }

    my $action_todo;
    do {
        my $ok = eval {
            $action_todo = $self->_run_service();
            1;
        };

        $action_todo //= 0;

        if ($ok) {

            # only notify a success when reaching the last stage
            if ( $stage == VALID_STAGES ) {
                Elevate::StageFile::update_stage_file( { status => q[success] } );
                $self->_notify_success();
                Elevate::StageFile::create_success_file();
            }

            if ( $action_todo == ACTION_PAUSE_REQUESTED ) {
                Elevate::StageFile::update_stage_file( { status => q[paused] } );
            }
            elsif ( $action_todo == ACTION_REBOOT_NEEDED ) {
                $self->reboot();
            }

        }
        else {
            my $error = $@ // q[Unknown error];

            Elevate::StageFile::update_stage_file( { status => q[failed] } );
            $self->_notify_error($error);

            LOGDIE($error);
        }
    } while ( $action_todo == ACTION_CONTINUE );

    return $action_todo;
}

sub check_and_create_pidfile ($self) {
    my $upid = Cpanel::PID->new( { pid_file => Elevate::Constants::PID_FILE } );

    if ( $upid->create_pid_file() != 1 ) {
        die qq[Another process is already running. Please wait for it to finish.\n];
    }

    return $upid;
}

sub check_status ($self) {
    my $stage = Elevate::Stages::get_stage();

    if ( !$stage ) {
        Elevate::Logger::ERROR_nolog('Elevation process has not started yet.');
        return;
    }

    my $status = $self->get_current_status();

    my $max_stage = VALID_STAGES;

    if ( $status eq 'success' ) {
        say q[success];
    }
    elsif ( $status eq 'paused' ) {
        my $paused_file = PAUSE_ELEVATE_TOUCHFILE;
        say qq[Paused at stage $stage / $max_stage please read more from $paused_file];
    }
    elsif ( $status eq 'running' ) {
        say qq[Running stage $stage / $max_stage];
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

sub _notify_success ($self) {

    my $upgrade_from_name  = Elevate::OS::pretty_name();
    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $msg = <<"EOS";
The cPanel & WHM server has completed the elevation process from $upgrade_from_name to $pretty_distro_name.
EOS

    if ( my $warnings = Elevate::StageFile::read_stage_file( 'final_notifications', [] ) ) {
        if ( scalar @$warnings ) {
            $msg .= "\nThe update to $pretty_distro_name was successful but please note that one ore more notifications require your attention:\n";

            foreach my $w ( reverse @$warnings ) {    # restore insert order
                $msg .= "\n* $w\n";
            }
        }
    }

    Elevate::Notify::send_notification( qq[Successfully updated to $pretty_distro_name] => $msg, is_success => 1 );

    return;
}

sub _notify_error ( $self, $error = '' ) {

    my $stage = Elevate::Stages::get_stage();

    my $msg = <<"EOS";
The elevation process failed during stage $stage.

You can continue the process after fixing the errors by running:

    $0 --continue

You can check the error log by running:

    $0

Last Error:

$error

EOS

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
    Elevate::Notify::send_notification( qq[Failed to update to $pretty_distro_name] => $msg );

    return;
}

sub _run_service ($self) {

    my $stage = Elevate::Stages::get_stage();

    print_box( "Starting stage $stage of " . VALID_STAGES );

    $self->_wait_on_pause();    # handle pause when requested

    # sanity check
    if ( Cpanel::OS::major() == 8 && 2 <= $stage && $stage <= 3 ) {    ## no critic(Cpanel::CpanelOS)
        WARN( "Detected " . Cpanel::OS::pretty_distro() . " while running stage $stage: swtiching to stage 4" );
        $stage = 4;
        Elevate::Stages::update_stage_number($stage);
    }

    return $stage == 1
      ? $self->run_stage_1()                                                       # Sanity check & install elevate service
      : $stage == 2 ? $self->run_stage_2()                                         # Update the current distro packages then reboot
      : $stage == 3 ? $self->run_stage_3()                                         # Prep leapp & run leapp process
      : $stage == 4 ? $self->run_stage_4()                                         # reboot on AlmaLinux 8: restore packages
      : $stage == 5 ? $self->run_stage_5()                                         # Final checks and cleanup
      :               die "Unknown stage '$stage'. I don't know how to proceed";

}

sub _wait_on_pause ($self) {

    my $pause_file = PAUSE_ELEVATE_TOUCHFILE;
    return unless -e $pause_file;

    Elevate::StageFile::update_stage_file( { status => q[paused] } );

    WARN( <<~"EOS" );
    The elevation process is currently paused by $pause_file
    Please read the file for more details.
    EOS

    while ( -e $pause_file ) {
        sleep 5;
    }

    Elevate::StageFile::update_stage_file( { status => q[running] } );

    my $stage = Elevate::Stages::get_stage();
    INFO("The pause file was removed. Continuing elevate process to stage $stage.");

    return 1;
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
            exit 1;    ## no critic(Cpanel::NoExitsFromSubroutines)
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

    Elevate::Marker::startup();

    Elevate::Motd->setup();

    if ( !$self->should_run_distro_upgrade() ) {
        Elevate::Stages::bump_stage();
        return ACTION_CONTINUE;
    }

    $self->run_component_once( 'Grub2' => 'mark_cmdline' );

    return ACTION_REBOOT_NEEDED;
}

=head2 run_stage_2

Update the current distro packages then reboot.

=cut

sub run_stage_2 ($self) {

    $self->run_component_once( 'Grub2' => 'verify_cmdline' );

    $self->ssystem(qw{/usr/bin/yum clean all});
    $self->ssystem_and_die(qw{/scripts/update-packages});
    $self->ssystem_and_die(qw{/usr/bin/yum -y update});

    # This needs to happen before the database upgrade because
    # it will remove the packages we want to detect
    $self->run_component_once( 'PackageRestore' => 'pre_distro_upgrade' );

    # This needs to execute before we disable cPanel services
    # or exporting the CCS data will fail
    $self->run_component_once( 'CCS'             => 'pre_distro_upgrade' );
    $self->run_component_once( 'DatabaseUpgrade' => 'pre_distro_upgrade' );

    # This disable cPanel services
    $self->run_component_once( 'cPanelPrep' => 'pre_distro_upgrade' );

    $self->run_component_once( 'SSH'        => 'pre_distro_upgrade' );
    $self->run_component_once( 'AutoSSL'    => 'pre_distro_upgrade' );
    $self->run_component_once( 'KernelCare' => 'pre_distro_upgrade' );
    $self->run_component_once( 'Grub2'      => 'pre_distro_upgrade' );
    $self->run_component_once( 'NICs'       => 'pre_distro_upgrade' );

    # Imunify depends on EA4 so the Imunify component needs to
    # run before EA4 is removed.  However, Imunify 360 can provide
    # hardened PHP so the EA4 profile backup needs to run before
    # Imunify is removed, so I split some of the EA4 logic out
    # to be executed before Imunify and left the removal until
    # after Imunify
    $self->run_component_once( 'EA4'     => 'pre_imunify' );
    $self->run_component_once( 'Imunify' => 'pre_distro_upgrade' );
    $self->run_component_once( 'PECL'    => 'pre_distro_upgrade' );
    $self->run_component_once( 'EA4'     => 'pre_distro_upgrade' );

    # This reboot will invalidate the cPanel license causing
    # further whmapi1 calls to fail until stage 4
    # if the NICs need to be renamed
    return ACTION_REBOOT_NEEDED;
}

=head2 run_stage_3

Setup the elevate-release-latest-el7 repo from the appropriate fork and install
leapp Packages.  Prepare the cPnael packages for the update.

Remove some known conflicting packages. (Reinstall later).

Provide answers to a few leapp questions.

Attempt to perform the leapp upgrade itself.
In case of failure you probably want to reply to a few extra questions or remove
some conflicting packages.

=cut

sub run_stage_3 ($self) {

    $self->run_once('run_final_components_pre_distro_upgrade');

    if ( !$self->should_run_distro_upgrade() ) {
        return $self->_request_to_upgrade_distro_manually();
    }

    $self->run_once(
        install_leapp => sub {
            $self->leapp->install();
            $self->leapp->remove_kernel_devel();
        },
    );

    $self->leapp->upgrade();

    WARN(<<~'EOS');
    Rebooting for distro upgrade. This will take over 10 minutes to run.
    Do not interrupt power during this event or you will corrupt your system.
    EOS

    return ACTION_REBOOT_NEEDED;

    # This takes a while because on reboot it's installing 800 packages
}

sub _request_to_upgrade_distro_manually ($self) {

    my $pause_file = PAUSE_ELEVATE_TOUCHFILE;

    my $txt = <<"EOS";
The cPanel elevation process is currently paused.
You should upgrade the distribution manually.

After a successful upgrade, you can then remove the file
    rm -f $pause_file
to let the elevation process continue and update cPanel for the updated distribution.
EOS

    WARN($txt);
    File::Slurper::write_text( $pause_file, $txt );

    return ACTION_PAUSE_REQUESTED;
}

=head2 run_stage_4

At this stage, we should now be run the upgraded OS (i.e. AlmaLinux 8).
Update cPanel product for the new distro.

Restore removed packages during the previous stage.

=cut

sub run_stage_4 ($self) {
    Cpanel::OS::flush_disk_caches();
    Cpanel::OS::clear_cache_after_cloudlinux_update();

    # 10 minute timeout if no completion is seen.
    unless ( $self->leapp->wait_for_leapp_completion ) {
        my $log_file = Elevate::Constants::LOG_FILE;
        die(<<~"END");
        The LEAPP upgrade process did not succeed
        Review the log at $log_file for more details
        END
    }

    if ( Cpanel::OS::major() != 8 ) {    ## no critic(Cpanel::CpanelOS)
        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
        my $current_distro     = Cpanel::OS::pretty_distro();

        if ( Cpanel::OS::major() == 7 ) {    ## no critic(Cpanel::CpanelOS)
            WARN("Detected $current_distro from stage 4, reverting back to stage 3.");
            Elevate::Stages::update_stage_number(3);
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

    my $stash = Elevate::StageFile::read_stage_file();

    $stash->{stage4} //= {};    # run once each blocks

    $self->run_component_once( 'RpmDB', => 'post_distro_upgrade' );

    $self->run_once(
        restore_cpanel_services => sub {
            $self->enable_all_cpanel_services();
            $self->stop_services_before_upcp();
            $self->clear_cpanel_caches();

            return;
        }
    );

    $self->run_component_once( 'Imunify' => 'post_distro_upgrade' );
    $self->run_component_once( 'EA4'     => 'post_distro_upgrade' );

    $self->run_once(
        upcp => sub {

            {
                # MySQL server is not upgraded at this point - treat the upcp like a fresh install
                local $ENV{'CPANEL_BASE_INSTALL'} = 1;
                $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/upcp.static --sync});
            }

            # cleanup the license: cpsanitycheck.so binary is compiled for a different distro
            unlink('/usr/local/cpanel/cpsanitycheck.so');
            $self->ssystem(qw{/usr/local/cpanel/cpkeyclt});

            return;
        }
    );

    $self->post_distro_upgrade_update_restore();

    $self->run_component_once( 'UnconvertedModules' => 'post_distro_upgrade' );

    # run upcp a second time as we had to run it before with CPANEL_BASE_INSTALL=1
    $self->run_once(
        upcp_second_run => sub {
            $self->ssystem_and_die(qw{/usr/local/cpanel/scripts/upcp.static --sync});
        }
    );

    $self->run_component_once( 'CCS' => 'post_distro_upgrade' );

    return ACTION_REBOOT_NEEDED;
}

=head2 run_stage_5

Final checks and cleanup.
The elevate-cpanel service is now removed.

=cut

sub run_stage_5 ($self) {
    return 0 if $self->post_upgrade_check();

    # we cannot stop the service ( ourself )
    $self->service->disable;
    unlink Elevate::Constants::PID_FILE;
    unlink Elevate::Constants::CHKSRVD_SUSPEND_FILE;
    my $el_backup_dir = Elevate::Constants::ELEVATE_BACKUP_DIR;
    File::Path::remove_tree($el_backup_dir) if -d $el_backup_dir;

    $self->run_component_once( 'Grub2' => 'post_distro_upgrade' );

    Elevate::Marker::success();

    $self->restore_outdated_services();

    INFO("Updating all packages before final reboot");
    $self->ssystem(qw{/usr/bin/dnf -y --allowerasing update});

    Elevate::Motd->cleanup();
    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
    print_box("Great SUCCESS! Your upgrade to $pretty_distro_name is complete.");

    return ACTION_REBOOT_NEEDED;
}

sub run_component_once ( $self, $name, $function ) {

    my $component = $self->get_component($name);
    my $label     = "component:$name:$function";
    my $sub       = $component->can($function)     #
      or die qq[Missing functon $function from component '$name'];

    my $run = sub {
        DEBUG("Running '$function' from $name component.");
        return $sub->($component);
    };

    return $self->run_once( $label, $run );
}

sub run_once ( $self, $label, $code = undef ) {

    die unless defined $label;

    $code //= cpev->can($label) || Carp::confess(qq[Missing function '$label']);

    die unless ref $code eq 'CODE';

    my $current_stage = Elevate::Stages::get_stage() // 0;
    my $stage_name    = 'stage' . $current_stage;

    my $stash = Elevate::StageFile::read_stage_file();
    $stash->{'_run_once'} //= {};

    my $full_label = $stage_name . '_' . $label;

    # already run one time successfully
    if ( $stash->{'_run_once'}->{$full_label} ) {
        INFO( sprintf( "Stage %d: skipping %s (already run)", $current_stage, $label ) );
        return 1;
    }

    $code->($self);

    # successfully run that block
    Elevate::StageFile::update_stage_file( { _run_once => { $full_label => 1 } } );

    return;
}

sub _sanity_check {
    return 1 if -x $0;

    chmod 0700 => $0;

    return 1 if -x $0;

    Elevate::Logger::ERROR_nolog("The script $0 is not executable, please fix it before running it again.");

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

sub print_box_no_log ($message) {

    say( "#" x 90 );
    say("#");
    foreach my $line ( split( "\n", $message ) ) {
        say("# $line");
    }
    say("#");
    say( "#" x 90 );

    return;
}

sub restore_outdated_services ($self) {

    my $outdated_services_file = Elevate::Constants::IGNORE_OUTDATED_SERVICES_FILE;

    return unless -e $outdated_services_file;

    my $content = File::Slurper::read_binary($outdated_services_file) // '';

    my $service_name = $self->service->short_name;

    if ( $content =~ s{^$service_name$}{}gm ) {
        1 while chomp $content;
        if ( $content =~ m{^\s*\z} ) {
            unlink $outdated_services_file;
            return 2;
        }
        else {
            $content .= "\n";
            File::Slurper::write_binary( $outdated_services_file, $content );
            return 1;
        }
    }

    return;
}

sub enable_all_cpanel_services ($self) {
    my $services = Elevate::StageFile::read_stage_file( 'disabled_cpanel_services', [] );
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

# remove and store
sub run_final_components_pre_distro_upgrade ($self) {

    # order matters
    $self->run_component_once( 'RmMod'            => 'pre_distro_upgrade' );
    $self->run_component_once( 'MySQL'            => 'pre_distro_upgrade' );
    $self->run_component_once( 'PostgreSQL'       => 'pre_distro_upgrade' );
    $self->run_component_once( 'Repositories'     => 'pre_distro_upgrade' );
    $self->run_component_once( 'cPanelPlugins'    => 'pre_distro_upgrade' );
    $self->run_component_once( 'PerlXS'           => 'pre_distro_upgrade' );
    $self->run_component_once( 'WPToolkit'        => 'pre_distro_upgrade' );
    $self->run_component_once( 'InfluxDB'         => 'pre_distro_upgrade' );
    $self->run_component_once( 'JetBackup'        => 'pre_distro_upgrade' );
    $self->run_component_once( 'NixStats'         => 'pre_distro_upgrade' );
    $self->run_component_once( 'LiteSpeed'        => 'pre_distro_upgrade' );
    $self->run_component_once( 'AbsoluteSymlinks' => 'pre_distro_upgrade' );
    $self->run_component_once( 'ELS'              => 'pre_distro_upgrade' );
    $self->run_component_once( 'R1Soft'           => 'pre_distro_upgrade' );
    $self->run_component_once( 'Panopta'          => 'pre_distro_upgrade' );
    $self->run_component_once( 'Acronis'          => 'pre_distro_upgrade' );
    $self->run_component_once( 'RpmDB'            => 'pre_distro_upgrade' );    # remove the RPMs last

    return;
}

sub post_distro_upgrade_update_restore ($self) {

    INFO('Removing leapp from excludes in /etc/yum.conf');
    my $txt = eval { File::Slurper::read_text("/etc/yum.conf") };
    if ( length $txt ) {
        $txt =~ s/\s*python2-leapp,snactor,leapp-upgrade-el7toel8,leapp//ms;
        File::Slurper::write_text( "/etc/yum.conf", $txt );
    }

    # plugins can use MySQL - restore database earlier
    $self->run_component_once( 'MySQL'           => 'post_distro_upgrade' );
    $self->run_component_once( 'PerlXS'          => 'post_distro_upgrade' );
    $self->run_component_once( 'PostgreSQL'      => 'post_distro_upgrade' );
    $self->run_component_once( 'cPanelPlugins'   => 'post_distro_upgrade' );
    $self->run_component_once( 'DatabaseUpgrade' => 'post_distro_upgrade' );
    $self->run_component_once( 'PECL'            => 'post_distro_upgrade' );
    $self->run_component_once( 'WPToolkit'       => 'post_distro_upgrade' );
    $self->run_component_once( 'InfluxDB'        => 'post_distro_upgrade' );
    $self->run_component_once( 'JetBackup'       => 'post_distro_upgrade' );
    $self->run_component_once( 'Kernel'          => 'post_distro_upgrade' );
    $self->run_component_once( 'KernelCare'      => 'post_distro_upgrade' );
    $self->run_component_once( 'NixStats'        => 'post_distro_upgrade' );
    $self->run_component_once( 'LiteSpeed'       => 'post_distro_upgrade' );
    $self->run_component_once( 'R1Soft'          => 'post_distro_upgrade' );
    $self->run_component_once( 'PackageRestore'  => 'post_distro_upgrade' );
    $self->run_component_once( 'Acronis'         => 'post_distro_upgrade' );

    return;
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

my $yum_list_cache;

sub yum_list ( $invalidate_cache = 0 ) {    # FIXME isolate to its own namespace
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

    $self->ssystem( qw{/usr/bin/yum -y erase}, @to_remove );

    return;
}

sub post_upgrade_check ($self) {

    my $expect_distro = Elevate::OS::default_upgrade_to();
    $expect_distro = lc $expect_distro;

    unless ( Cpanel::OS::major() == 8 && Cpanel::OS::distro() eq $expect_distro ) {    ## no critic(Cpanel::CpanelOS)
        my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
        die "Your distro does not look like $pretty_distro_name.\n";
    }

    # call a cpanel binary
    $self->ssystem_and_die(qw{/usr/local/cpanel/cpanel -V});

    return 0;
}

# TODO: We're going to need to store reboot time so we know if the last reboot has happened when we re-run the script.

sub should_run_distro_upgrade ($self) {

    # we store the upgrade_distro_manually option, but prefer using a positive check instead
    # we need to check to see if the CLI option is passed here too in order
    # to allow users to run this script with the '--check --upgrade-distro-manually', etc. options
    my $manual_distro_upgrade = scalar grep { $self->getopt($_) || Elevate::StageFile::read_stage_file( tr/-/_/r, 0 ) } qw/upgrade-distro-manually no-leapp/;
    return !$manual_distro_upgrade;
}

sub get_current_status ($self) {
    return Elevate::StageFile::read_stage_file( 'status', 'unknown' );
}

sub reboot ($self) {
    Elevate::Stages::bump_stage();

    # protection
    my $stage = Elevate::Stages::get_stage();

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
    return;
}

sub request_manual_reboots() {
    return !!Elevate::StageFile::read_stage_file( 'manual_reboots', 0 );
}

1;
