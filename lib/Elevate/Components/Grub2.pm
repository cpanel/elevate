package Elevate::Components::Grub2;

=encoding utf-8

=head1 NAME

Elevate::Components::Grub2

=head2 check

Ensure systems upgrading with leapp are using grub2 since leapp depends on it

=head2 pre_distro_upgrade

Workaround grub2 specific issues if necessary

=head2 post_distro_upgrade

Ensure expected kernelopts are set for grub2 systems

=head2 mark_cmdline

Add a random option to the grub cmdline

=head2 verify_cmdline

Verify that the option is present after a reboot and block if it is not

=head2 TODO

Split mark_cmdline and verify_cmdline to its own component

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::StageFile ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();
use Cpanel::SafeRun::Object ();

use parent qw{Elevate::Components::Base};

our $GRUB2_PREFIX_DEBIAN = '/boot/grub';
our $GRUB2_PREFIX_RHEL   = '/boot/grub2';

use constant GRUB2_WORKAROUND_NONE => 0;
use constant GRUB2_WORKAROUND_OLD  => 1;
use constant GRUB2_WORKAROUND_NEW  => 2;

use constant GRUB2_WORKAROUND_UNCERTAIN => -1;

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
            my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
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

sub _update_grub2_workaround_if_needed ($self) {

    my $grub2_info = Elevate::StageFile::read_stage_file('grub2_workaround');
    return unless $grub2_info->{'needs_workaround_update'};

    my $grub_dir  = $GRUB2_PREFIX_DEBIAN;
    my $grub2_dir = $GRUB2_PREFIX_RHEL;

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

    my $grub_dir  = $GRUB2_PREFIX_DEBIAN;
    my $grub2_dir = $GRUB2_PREFIX_RHEL;
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

sub check ($self) {

    return 1 unless $self->should_run_distro_upgrade;    # skip when --upgrade-distro-manually is provided

    my $ok = 1;
    $ok = 0 unless $self->_blocker_grub2_workaround;
    $ok = 0 unless $self->_blocker_blscfg;
    $ok = 0 unless $self->_blocker_grub_not_installed;
    $ok = 0 unless $self->_blocker_grub_config_missing;
    return $ok;
}

sub _blocker_grub2_workaround ($self) {
    my $state = _grub2_workaround_state();
    if ( $state == GRUB2_WORKAROUND_OLD ) {
        my ( $deb, $rhel ) = ( $GRUB2_PREFIX_DEBIAN, $GRUB2_PREFIX_RHEL );
        WARN( <<~EOS );
        $deb/grub.cfg is currently a symlink to $rhel/grub.cfg. Your provider
        may have added this to support booting your server using their own
        instance of the GRUB2 bootloader, one which looks for its
        configuration, boot entries, and modules in a different location from
        where your operating system stores this data. In order to allow the
        process to complete successfully, the upgrade process will rename the
        current $deb directory, re-create $deb as a symlink to $rhel,
        and then copy as much of the old $deb into $rhel as possible.
        EOS
        Elevate::StageFile::update_stage_file( { 'grub2_workaround' => { 'needs_workaround_update' => 1 } } ) if !$self->is_check_mode();    # don't update stage file if this is just a check
    }
    elsif ( $state == GRUB2_WORKAROUND_UNCERTAIN ) {

        return $self->has_blocker( <<~EOS );
        The configuration of the GRUB2 bootloader does not match the
        expectations of this script. For more information, see the output of
        the script when run at the console:

        /scripts/elevate-cpanel --check

        If your GRUB2 configuration has not been customized, you may want
        to consider reaching out to cPanel Support for assistance:
        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS
    }

    return 0;
}

sub _blocker_blscfg ($self) {

    my $grub_enable_blscfg = _parse_shell_variable( Elevate::Constants::DEFAULT_GRUB_FILE, 'GRUB_ENABLE_BLSCFG' );

    return $self->has_blocker( <<~EOS ) if defined $grub_enable_blscfg && $grub_enable_blscfg ne 'true';
    Disabling the BLS boot entry format prevents the resulting system from
    adding kernel updates to any boot loader configuration, because the old
    utility responsible for maintaining native GRUB2 boot loader entries was
    removed and replaced with a wrapper around the new utility, which only
    understands BLS format. This means that the old kernel will be used on
    reboot, unless the GRUB2 configuration file is manually edited to load the
    new kernel. Furthermore, after a few kernel updates, the DNF package
    manager may begin to remove old kernels, including the one still used in
    the configuration file. If that happens, the system will fail to come back
    after a subsequent reboot.

    The safe option is to remove the following line in /etc/default/grub:

    GRUB_ENABLE_BLSCFG=false

    or to change it so that it is set to "true" instead.
    EOS

    return 0;
}

sub _blocker_grub_not_installed ($self) {

    return 0 if Cpanel::Pkgr::is_installed('grub2-pc');

    return $self->has_blocker( <<~EOS );
    The grub2-pc package is not installed. The GRUB2 boot loader is
    required to upgrade via leapp.

    If you need assistance, open a ticket with cPanel Support, as outlined here
    https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
    EOS
}

sub _blocker_grub_config_missing ($self) {

    if (   ( !-f '/boot/grub2/grub.cfg' || !-s '/boot/grub2/grub.cfg' )
        && ( !-f '/boot/grub/grub.cfg' || !-s '/boot/grub/grub.cfg' ) ) {

        return $self->has_blocker( <<~EOS );
        The GRUB2 config file is missing.

        If you need assistance, open a ticket with cPanel Support, as outlined here
        https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/
        EOS
    }

    return 0;
}

sub _parse_shell_variable ( $path, $varname ) {

    my ( undef, $dir, $file ) = File::Spec->splitpath($path);
    $dir = File::Spec->canonpath($dir);

    # drop privileges and run bash in restricted mode
    my $bash_sr = Cpanel::SafeRun::Object->new(
        program => Cpanel::Binaries::path('bash'),
        args    => [
            '--restricted',
            '-c',
            qq(set -ux ; [ "x\$PWD" = "x$dir" ] || exit 72 ; source $file ; echo "\$$varname"),
        ],
        before_exec => sub {
            chdir $dir;
            Cpanel::AccessIds::SetUids::setuids('nobody');
        },
    );

    return undef if $bash_sr->CHILD_ERROR && $bash_sr->error_code == 127;
    $bash_sr->die_if_error();    # bail out if something else went wrong

    my $value = $bash_sr->stdout;
    chomp $value;
    return $value;
}

sub _grub2_workaround_state () {

    # If /boot/grub DNE, user probably didn't want a workaround:
    return GRUB2_WORKAROUND_NONE if !-e $GRUB2_PREFIX_DEBIAN;

    if ( -l $GRUB2_PREFIX_DEBIAN ) {
        my $dest = Cwd::realpath($GRUB2_PREFIX_DEBIAN);
        if ( !defined($dest) ) {
            ERROR( $GRUB2_PREFIX_DEBIAN . " is a symlink but realpath() failed: $!" ) unless defined($dest);
            return GRUB2_WORKAROUND_UNCERTAIN;
        }

        # If /boot/grub symlink pointing to /boot/grub2, the updated workaround is present:
        if ( $dest eq $GRUB2_PREFIX_RHEL ) {
            return GRUB2_WORKAROUND_NEW if -d $dest;
            ERROR( $GRUB2_PREFIX_DEBIAN . " does not ultimately link to /boot/grub2." );
            return GRUB2_WORKAROUND_UNCERTAIN;    # ...unless /boot/grub2 isn't a directory.
        }
    }

    # If /boot/grub neither symlink nor directory, we don't know what is going on:
    elsif ( !-d $GRUB2_PREFIX_DEBIAN ) {
        ERROR( $GRUB2_PREFIX_DEBIAN . " is neither symlink nor directory." );
        return GRUB2_WORKAROUND_UNCERTAIN;
    }

    my ( $grub_cfg, $grub2_cfg ) = map { $_ . "/grub.cfg" } ( $GRUB2_PREFIX_DEBIAN, $GRUB2_PREFIX_RHEL );

    # If /boot/grub/grub.cfg DNE, user probably didn't want a workaround:
    return GRUB2_WORKAROUND_NONE if !-e $grub_cfg;

    if ( -l $grub_cfg ) {
        my $dest_cfg = Cwd::realpath($grub_cfg);
        if ( !defined($dest_cfg) ) {
            ERROR("$grub_cfg is a symlink but realpath() failed: $!");
            return GRUB2_WORKAROUND_UNCERTAIN;
        }

        # If /boot/grub/grub.cfg is a symlink pointing to /boot/grub2/grub.cfg, the old workaround is present:
        if ( $dest_cfg eq $grub2_cfg ) {
            return GRUB2_WORKAROUND_OLD if -f $dest_cfg;
            ERROR("$dest_cfg is not a regular file.");
            return GRUB2_WORKAROUND_UNCERTAIN;    # ...unless /boot/grub2/grub.cfg isn't a regular file.
        }
    }

    # If /boot/grub/grub.cfg exists but isn't a symlink, we don't know what is going on:
    ERROR("$grub_cfg exists but is not a symlink which ultimately links to $grub2_cfg.");
    return GRUB2_WORKAROUND_UNCERTAIN;
}

1;
