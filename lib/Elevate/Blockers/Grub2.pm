package Elevate::Blockers::Grub2;

=encoding utf-8

=head1 NAME

Elevate::Blockers::Grub2

Blocker to check compatibility with Grub2 configuration.

=cut

use cPstrict;

use Cpanel::Pkgr ();

use Elevate::Constants ();
use Elevate::StageFile ();

use parent qw{Elevate::Blockers::Base};

use Cwd           ();
use Log::Log4perl qw(:easy);

use constant GRUB2_WORKAROUND_NONE => 0;
use constant GRUB2_WORKAROUND_OLD  => 1;
use constant GRUB2_WORKAROUND_NEW  => 2;

use constant GRUB2_WORKAROUND_UNCERTAIN => -1;

sub GRUB2_PREFIX_DEBIAN { return '/boot/grub' }
sub GRUB2_PREFIX_RHEL   { return '/boot/grub2' }

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
        my ( $deb, $rhel ) = ( GRUB2_PREFIX_DEBIAN, GRUB2_PREFIX_RHEL );
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

# TODO: This should probably return warnings/errors rather than directly printing to the log.
sub _grub2_workaround_state () {

    # If /boot/grub DNE, user probably didn't want a workaround:
    return GRUB2_WORKAROUND_NONE if !-e GRUB2_PREFIX_DEBIAN;

    if ( -l GRUB2_PREFIX_DEBIAN ) {
        my $dest = Cwd::realpath(GRUB2_PREFIX_DEBIAN);
        if ( !defined($dest) ) {
            ERROR( GRUB2_PREFIX_DEBIAN . " is a symlink but realpath() failed: $!" ) unless defined($dest);
            return GRUB2_WORKAROUND_UNCERTAIN;
        }

        # If /boot/grub symlink pointing to /boot/grub2, the updated workaround is present:
        if ( $dest eq GRUB2_PREFIX_RHEL ) {
            return GRUB2_WORKAROUND_NEW if -d $dest;
            ERROR( GRUB2_PREFIX_DEBIAN . " does not ultimately link to /boot/grub2." );
            return GRUB2_WORKAROUND_UNCERTAIN;    # ...unless /boot/grub2 isn't a directory.
        }
    }

    # If /boot/grub neither symlink nor directory, we don't know what is going on:
    elsif ( !-d GRUB2_PREFIX_DEBIAN ) {
        ERROR( GRUB2_PREFIX_DEBIAN . " is neither symlink nor directory." );
        return GRUB2_WORKAROUND_UNCERTAIN;
    }

    my ( $grub_cfg, $grub2_cfg ) = map { $_ . "/grub.cfg" } ( GRUB2_PREFIX_DEBIAN, GRUB2_PREFIX_RHEL );

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
