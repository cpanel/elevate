package Elevate::Components::Grub2;

=encoding utf-8

=head1 NAME

Elevate::Components::Grub2

Logic to update and fix grub2 configuration.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::StageFile ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();
use Cpanel::SafeRun::Object ();

use parent qw{Elevate::Components::Base};

use Elevate::Blockers ();

use constant GRUB_EDITENV  => '/usr/bin/grub2-editenv';
use constant GRUB_ENV_FILE => '/boot/grub2/grubenv';

use constant GRUBBY_PATH  => '/usr/sbin/grubby';
use constant CMDLINE_PATH => '/proc/cmdline';

# In place of Unix::Sysexits:
use constant EX_UNAVAILABLE => 69;

sub _call_grubby ( $self, @args ) {

    my %opts = (
        should_capture_output => 0,
        should_hide_output    => 0,
        die_on_error          => 0,
    );

    if ( ref $args[0] eq 'HASH' ) {
        my %opt_args = %{ shift @args };
        foreach my $key ( keys %opt_args ) {
            $opts{$key} = $opt_args{$key};
        }
    }

    unshift @args, GRUBBY_PATH;

    return $opts{die_on_error} ? $self->ssystem_and_die(@args) : $self->ssystem( \%opts, @args );
}

sub _default_kernel ($self) {
    return $self->_call_grubby( { should_capture_output => 1, should_hide_output => 1 }, '--default-kernel' )->{'stdout'}->[0] // '';
}

sub _persistent_id {
    my $id = Elevate::StageFile::read_stage_file( 'bootloader_random_tag', '' );
    return $id if $id;

    $id = int( rand(100000) );
    Elevate::StageFile::update_stage_file( { 'bootloader_random_tag', $id } );
    return $id;
}

sub mark_cmdline ($self) {
    my $arg = "elevate-" . _persistent_id;
    INFO("Marking default boot entry with additional parameter \"$arg\".");

    my $kernel_path = $self->_default_kernel;
    $self->_call_grubby( { die_on_error => 1 }, "--update-kernel=$kernel_path", "--args=$arg" );

    return;
}

sub _remove_but_dont_stop_service ($self) {

    $self->cpev->service->disable();
    $self->ssystem( '/usr/bin/systemctl', 'daemon-reload' );

    return;
}

sub verify_cmdline ($self) {
    if ( $self->cpev->should_run_distro_upgrade() ) {
        my $arg = "elevate-" . _persistent_id;
        INFO("Checking for \"$arg\" in booted kernel's command line...");

        my $kernel_cmdline = eval { File::Slurper::read_binary(CMDLINE_PATH) } // '';
        DEBUG( CMDLINE_PATH . " contains: $kernel_cmdline" );

        my $detected = scalar grep { $_ eq $arg } split( ' ', $kernel_cmdline );
        if ($detected) {
            INFO("Parameter detected; restoring entry to original state.");
        }
        else {
            ERROR("Parameter not detected. Attempt to upgrade is being aborted.");
        }

        my $kernel_path = $self->_default_kernel;
        my $result      = $self->_call_grubby( "--update-kernel=$kernel_path", "--remove-args=$arg" );
        WARN("Unable to restore original command line. This should not cause problems but is unusual.") if $result != 0;

        if ( !$detected ) {

            # Can't use _notify_error as in run_service_and_notify, because that
            # tells you to use --continue, which won't work here due to the
            # do_cleanup invocation:
            my $stage              = Elevate::Stages::get_stage();
            my $pretty_distro_name = $self->cpev->upgrade_to_pretty_name();
            my $msg                = <<"EOS";
The elevation process failed during stage $stage.

Specifically, the script could not prove that the system has control over its
own boot process using the utilities the operating system provides.

For this reason, the elevation process has terminated before making any
irreversible changes.

You can check the error log by running:

    $0

Before you can run the elevation process, you must provide for the ability for
the system to manipulate its own boot process. Then you can start the elevation
process anew:

    $0 --start

EOS
            Elevate::Notify::send_notification( qq[Failed to update to $pretty_distro_name] => $msg );

            $self->cpev->do_cleanup(1);
            $self->_remove_but_dont_stop_service();

            exit EX_UNAVAILABLE;    ## no critic(Cpanel::NoExitsFromSubroutines)
        }
    }

    return;
}

sub pre_distro_upgrade ($self) {

    $self->run_once('_update_grub2_workaround_if_needed');    # required part
    $self->run_once('_merge_grub_directories_if_needed');     # best-effort part

    return;
}

sub GRUB2_PREFIX_DEBIAN { return '/boot/grub' }     # FIXME deduplicate & move to constant
sub GRUB2_PREFIX_RHEL   { return '/boot/grub2' }    # FIXME deduplicate & move to constant

sub _update_grub2_workaround_if_needed ($self) {

    my $grub2_info = Elevate::StageFile::read_stage_file('grub2_workaround');
    return unless $grub2_info->{'needs_workaround_update'};

    my $grub_dir  = GRUB2_PREFIX_DEBIAN;
    my $grub2_dir = GRUB2_PREFIX_RHEL;

    my $grub_bak;
    if ( $grub2_info->{'backup_dir'} ) {
        $grub_bak = $grub2_info->{'backup_dir'};
    }
    else {
        $grub_bak = $grub2_info->{'backup_dir'} = $grub_dir . '-' . time;
        Elevate::StageFile::update_stage_file( { 'grub2_workaround' => $grub2_info } );
    }

    rename $grub_dir, $grub_bak or LOGDIE("Unable to rename $grub_dir to $grub_bak: $!");    # failure on cross-device move is a feature
    symlink $grub2_dir, $grub_dir or do {
        rename $grub_bak, $grub_dir;                                                         # undo previous change on failure
        LOGDIE("Unable to create symlink $grub_dir to point to $grub2_dir");                 # symlink() doesn't set $!
    };

    return;
}

sub _merge_grub_directories_if_needed ($self) {

    my $grub2_info = Elevate::StageFile::read_stage_file('grub2_workaround');
    return unless $grub2_info->{'needs_workaround_update'};

    my $grub_dir  = GRUB2_PREFIX_DEBIAN;
    my $grub2_dir = GRUB2_PREFIX_RHEL;
    my $grub_bak  = $grub2_info->{'backup_dir'};

    my ( $skipped_copy, $failed_copy ) = ( 0, 0 );

    # If something goes wrong here, we should give up on the copy but allow the upgrade to continue.
    # Therefore, don't use LOGDIE() inside of the eval block.
    eval {
        my %grub2_entries;

        opendir my $grub2_dir_fh, $grub2_dir or die "Unable to open directory $grub2_dir: $!";
        while ( my $entry = readdir $grub2_dir_fh ) {
            $grub2_entries{$entry} = 1;
        }
        closedir $grub2_dir_fh;

        opendir my $grub_bak_fh, $grub_bak or die "Unable to open directory $grub_bak: $!";
        while ( my $entry = readdir $grub_bak_fh ) {

            next if $entry eq '.';
            next if $entry eq '..';

            # grub.cfg in the backup dir is the old symlink, so ignore it separately to avoid warnings:
            next if $entry eq "grub.cfg";

            if ( exists $grub2_entries{$entry} ) {
                $skipped_copy++;
                WARN("\"$grub_bak/$entry\" is not being copied to \"$grub2_dir/$entry\" because the destination already exists.");
                next;
            }

            if ( !File::Copy::Recursive::rcopy( "$grub_bak/$entry", "$grub2_dir/$entry" ) ) {
                $failed_copy++;
                WARN("Copying \"$grub_bak/$entry\" into \"$grub2_dir\" failed.");
            }
        }
        closedir $grub_bak_fh;
    };
    WARN("Unable to copy the contents of \"$grub_bak\" into \"$grub2_dir\": $@") if $@;

    my $log_file = Elevate::Constants::LOG_FILE;

    Elevate::Notify::add_final_notification( <<~EOS ) if ( $skipped_copy > 0 || $failed_copy > 0 );
        After converting "$grub_dir" from a directory to a symlink to
        "$grub2_dir", the upgrade process chose not to copy $skipped_copy
        entries from the old directory due to name conflicts, and it failed to
        copy $failed_copy entries due to system errors. The previous contents
        of "$grub_dir" are now located at "$grub_bak". See $log_file for
        further information.

        If you did not add these files or otherwise customize the boot loader
        configuration, you may ignore this message.
        EOS

    return;
}

sub post_distro_upgrade ($self) {

    # for an autofixer
    # return unless -e q[/var/cpanel/version/elevate];

    # check that the current kernel is using 'net.ifnames=0'
    my $proc_cmd_line = eval { File::Slurper::read_binary('/proc/cmdline') } // '';
    return unless $proc_cmd_line =~ m{net.ifnames=0};

    # check that grub contains the net.ifnames
    my $grub_conf = eval { File::Slurper::read_binary(Elevate::Constants::DEFAULT_GRUB_FILE) } // '';
    return unless length $grub_conf;
    return if $grub_conf =~ m/net.ifnames/;

    # add net.ifnames=0 if needed
    return unless $grub_conf =~ s/GRUB_CMDLINE_LINUX="(.+?)"/GRUB_CMDLINE_LINUX="$1 net.ifnames=0"/m;
    File::Slurper::write_binary( Elevate::Constants::DEFAULT_GRUB_FILE, $grub_conf );

    # Also save net.ifnames=0 to the GRUB environment:
    my $grubenv = Cpanel::SafeRun::Simple::saferunnoerror( GRUB_EDITENV, GRUB_ENV_FILE, 'list' );
    foreach my $line ( split "\n", $grubenv ) {
        my ( $name, $value ) = split "=", $line, 2;
        next unless $name eq "kernelopts";

        if ( $value !~ m/\bnet\.ifnames=/a ) {
            $line .= ( $line && $line !~ m/ $/ ? " " : "" ) . 'net.ifnames=0';
            Cpanel::SafeRun::Object->new_or_die(
                program => GRUB_EDITENV,
                args    => [
                    GRUB_ENV_FILE,
                    "set",
                    $line,
                ],
            );
            last;
        }
    }

    return 1;
}

1;
