package Elevate::Components::Grub2;

=encoding utf-8

=head1 NAME

Elevate::Components::Grub2

Logic to update and fix grub2 configuration.

=cut

use cPstrict;

use Elevate::Constants ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use Cpanel::JSON            ();
use Cpanel::Pkgr            ();
use Cpanel::SafeRun::Simple ();

use parent qw{Elevate::Components::Base};

use Elevate::Blockers ();

use constant GRUB_EDITENV  => '/usr/bin/grub2-editenv';
use constant GRUB_ENV_FILE => '/boot/grub2/grubenv';

sub pre_leapp ($self) {

    $self->run_once('_update_grub2_workaround_if_needed');    # required part
    $self->run_once('_merge_grub_directories_if_needed');     # best-effort part

    return;
}

sub GRUB2_PREFIX_DEBIAN { return '/boot/grub' }     # FIXME deduplicate & move to constant
sub GRUB2_PREFIX_RHEL   { return '/boot/grub2' }    # FIXME deduplicate & move to constant

sub _update_grub2_workaround_if_needed ($self) {

    my $grub2_info = cpev::read_stage_file('grub2_workaround');
    return unless $grub2_info->{'needs_workaround_update'};

    my $grub_dir  = GRUB2_PREFIX_DEBIAN;
    my $grub2_dir = GRUB2_PREFIX_RHEL;

    my $grub_bak;
    if ( $grub2_info->{'backup_dir'} ) {
        $grub_bak = $grub2_info->{'backup_dir'};
    }
    else {
        $grub_bak = $grub2_info->{'backup_dir'} = $grub_dir . '-' . time;
        cpev::update_stage_file( { 'grub2_workaround' => $grub2_info } );
    }

    rename $grub_dir, $grub_bak or LOGDIE("Unable to rename $grub_dir to $grub_bak: $!");    # failure on cross-device move is a feature
    symlink $grub2_dir, $grub_dir or do {
        rename $grub_bak, $grub_dir;                                                         # undo previous change on failure
        LOGDIE("Unable to create symlink $grub_dir to point to $grub2_dir");                 # symlink() doesn't set $!
    };

    return;
}

sub _merge_grub_directories_if_needed ($self) {

    my $grub2_info = cpev::read_stage_file('grub2_workaround');
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

sub post_leapp ($self) {

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
