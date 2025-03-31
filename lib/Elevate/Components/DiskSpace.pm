package Elevate::Components::DiskSpace;

=encoding utf-8

=head1 NAME

Elevate::Components::DiskSpace

=head2 check

Verify server has enough disk space to perform elevation

=head2 pre_distro_upgrade

Disable securetmp if it is installed on ubuntu only

=head2 check_tmp

Verify server has enough disk space to perform elevate after disabling
securetmp and block if it does not

=head2 post_distro_upgrade

Reenable securetmp if we disabled it

=cut

use cPstrict;

use File::Copy    ();
use File::Path    ();
use File::Slurper ();

use Cpanel::SafeRun::Simple ();

use Elevate::Constants        ();
use Elevate::OS               ();
use Elevate::StageFile        ();
use Elevate::SystemctlService ();

use parent qw{Elevate::Components::Base};

use Log::Log4perl qw(:easy);

use constant K   => 1;
use constant MEG => 1_024 * K;
use constant GIG => 1_024 * MEG;

use constant FSTAB_PATH          => '/etc/fstab';
use constant FSTAB_BACKUP_SUFFIX => 'elevate_backup';

use constant DISABLE_SECURETMP_TOUCHFILE => '/var/cpanel/disabled/securetmp';

sub check ($self) {    # $self is a cpev object here
    my $ok = _disk_space_check($self);
    $self->has_blocker(q[disk space issue]) unless $ok;

    return $ok;
}

sub _disk_space_check ($self) {

    # minimum disk space for some mount points
    # note we are not doing the sum per mount point
    #   - /boot is small enough
    #   - /usr/local/cpanel is not going to be used at the same time than /var/lib
    my $need_space = {
        '/boot'             => 200 * MEG,
        '/usr/local/cpanel' => 1.5 * GIG,    #
        '/var/lib'          => 5 * GIG,
        '/tmp'              => 5 * MEG,
        '/'                 => 5 * GIG,
    };

    # do-release-upgrade can fail with 500MB of space available in /tmp
    # so lets bump that requirement up
    # If securetmp is enabled, we will disable it
    $need_space->{'/tmp'} = 750 * MEG if Elevate::OS::needs_do_release_upgrade() && !$self->is_securetmp_installed();

    my @keys = ( sort keys %$need_space );

    my @df_cmd = ( qw{/usr/bin/df -k}, @keys );
    my $cmd    = join( ' ', @df_cmd );

    my $result = Cpanel::SafeRun::Simple::saferunnoerror(@df_cmd) // '';
    die qq[Failed to check disk space using: $cmd\n] if $?;

    my ( $header, @out ) = split( "\n", $result );

    if ( scalar @out != scalar @keys ) {
        my $count_keys = scalar @keys;
        my $count_out  = scalar @out;
        die qq[Fail: Cannot parse df output from: $cmd\n] . "# expected $count_keys lines ; got $count_out lines\n" . join( "\n", @out ) . "\n";
    }

    my @errors;

    my $ix = 0;
    foreach my $line (@out) {
        my $key = $keys[ $ix++ ];
        my ( undef, undef, undef, $available ) = split( /\s+/, $line );

        my $need = $need_space->{$key};

        next if $available > $need;

        my $str;
        if ( $need / GIG > 1 ) {
            $str = sprintf( "- $key needs %2.2f G => available %2.2f G", $need / GIG, $available / GIG );
        }
        else {
            $str = sprintf( "- $key needs %d M => available %d M", $need / MEG, $available / MEG );
        }

        push @errors, $str;
    }

    # everything is fine: check ok
    return 1 unless @errors;

    my $details = join( "\n", @errors );

    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();

    my $error = <<"EOS";
** Warning **: your system does not have enough disk space available to update to $pretty_distro_name

$details
EOS

    warn $error . "\n";

    return 0;    # error
}

sub is_securetmp_installed ($self) {
    my $fstab = File::Slurper::read_binary(FSTAB_PATH);
    return grep { $_ =~ /^\s*\/usr\/tmpDSK/ } split "\n", $fstab;
}

sub pre_distro_upgrade ($self) {
    return unless Elevate::OS::needs_do_release_upgrade();
    return unless $self->is_securetmp_installed();

    Elevate::StageFile::remove_from_stage_file('restore_fstab');

    my $fstab = File::Slurper::read_binary(FSTAB_PATH);
    my @lines = split "\n", $fstab;
    foreach my $line (@lines) {

        # Remove entry for securetmp
        $line = '' if $line =~ /^\s*\/usr\/tmpDSK/;

        # Remove /var/tmp entry if we added it
        $line = '' if $line =~ m{/tmp\s+/var/tmp\s+ext4\s+defaults,bind,noauto\s+0\s+0};
    }

    my $new_fstab = join "\n", @lines;
    $new_fstab .= "\n";

    File::Copy::cp( FSTAB_PATH, FSTAB_PATH . '.' . FSTAB_BACKUP_SUFFIX );
    File::Slurper::write_text( FSTAB_PATH, $new_fstab );

    $self->create_disable_securetmp_touchfile();

    Elevate::StageFile::update_stage_file( { restore_fstab => 1 } );
    return;
}

sub create_disable_securetmp_touchfile ($self) {
    system touch => DISABLE_SECURETMP_TOUCHFILE();
    return;
}

sub post_distro_upgrade ($self) {
    return unless Elevate::StageFile::read_stage_file('restore_fstab');
    return unless Elevate::OS::needs_do_release_upgrade();
    return unless -s FSTAB_PATH . '.' . FSTAB_BACKUP_SUFFIX;

    File::Copy::mv( FSTAB_PATH . '.' . FSTAB_BACKUP_SUFFIX, FSTAB_PATH );

    unlink DISABLE_SECURETMP_TOUCHFILE();

    # Clear out /tmp so we don't mount over it and hide disk space usage
    # Don't actually remove /tmp
    eval { File::Path::remove_tree( '/tmp', { keep_root => 1 } ) };

    return;
}

sub check_tmp ($self) {
    my $ok = $self->_disk_space_check();
    $self->has_blocker(q[disk space issue]) unless $ok;

    return if $ok;

    # Can't use _notify_error as in run_service_and_notify, because that
    # tells you to use --continue, which won't work here due to the
    # do_cleanup invocation:
    my $stage              = Elevate::Stages::get_stage();
    my $pretty_distro_name = Elevate::OS::upgrade_to_pretty_name();
    my $msg                = <<"EOS";
The elevation process failed during stage $stage.

Specifically, the script detected that there is not enough disk space in /tmp
to safely attempt to execute the distro upgrade tool.

For this reason, the elevation process has terminated before making any
irreversible changes.

You can check the error log by running:

    $0

Before you can run the elevation process, you will need to increase the disk space available in the /tmp directory. Then you can start the elevation process anew:

    $0 --start

EOS

    Elevate::Notify::send_notification( qq[Failed to update to $pretty_distro_name] => $msg );

    # Restore securetmp before exiting
    $self->post_distro_upgrade();

    $self->cpev->do_cleanup(1);
    $self->_remove_but_dont_stop_service();

    # Reboot the system a final time in order to ensure that to
    # properly remount securetmp
    $self->ssystem_and_die( '/usr/sbin/reboot', 'now' );
    exit Elevate::Constants::EX_UNAVAILABLE();    ## no critic(Cpanel::NoExitsFromSubroutines)
}

sub _remove_but_dont_stop_service ($self) {

    $self->cpev->service->disable();
    $self->ssystem( '/usr/bin/systemctl', 'daemon-reload' );

    return;
}

1;
