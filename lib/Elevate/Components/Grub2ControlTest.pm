package Elevate::Components::Grub2ControlTest;

=encoding utf-8

=head1 NAME

Elevate::Components::Grub2ControlTest

=head2 mark_cmdline

Add a random option to the grub cmdline

=head2 verify_cmdline

Verify that the option is present after a reboot and block if it is not

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();
use Elevate::StageFile ();

use Log::Log4perl qw(:easy);
use File::Slurper ();

use parent qw{Elevate::Components::Base};

use constant GRUBBY_PATH                  => '/usr/sbin/grubby';
use constant UPDATE_GRUB_PATH             => '/usr/sbin/update-grub';                            # This is an official alias for grub-mkconfig with the correct arguments
use constant GRUB_MKCONFIG_FRAG_DIR_PATH  => '/etc/default/grub.d';
use constant GRUB_MKCONFIG_FRAG_FILE_PATH => GRUB_MKCONFIG_FRAG_DIR_PATH . '/zzz-elevate.cfg';
use constant CMDLINE_PATH                 => '/proc/cmdline';
use constant ETC_DEFAULT_GRUB_PATH        => '/etc/default/grub';
use constant GRUB2_MKCONFIG               => '/usr/sbin/grub2-mkconfig';
use constant GRUB_CFG                     => '/boot/grub2/grub.cfg';

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

sub _call_update_grub ( $self, $opts = {} ) {
    die "Argument must be a hashref" unless ref $opts eq 'HASH';
    return $opts->{die_on_error} ? $self->ssystem_and_die(UPDATE_GRUB_PATH) : $self->ssystem(UPDATE_GRUB_PATH);
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

sub _add_kernel_arg ( $self, $arg ) {

    if ( Elevate::OS::bootloader_config_method() eq 'grubby' ) {
        my $kernel_path = $self->_default_kernel;
        $self->_call_grubby( { die_on_error => 1 }, "--update-kernel=$kernel_path", "--args=$arg" );
    }
    elsif ( Elevate::OS::bootloader_config_method() eq 'grub-mkconfig' ) {
        my $content = qq{GRUB_CMDLINE_LINUX_DEFAULT="\$GRUB_CMDLINE_LINUX_DEFAULT $arg"};
        File::Slurper::write_text( GRUB_MKCONFIG_FRAG_FILE_PATH, $content );
        $self->_call_update_grub( { die_on_error => 1 } );
    }
    else {
        LOGDIE("We don't know how to manipulate the bootloader!");
    }
    return;
}

sub _check_command_exists {
    if ( Elevate::OS::bootloader_config_method() eq 'grubby' ) {
        return -x GRUBBY_PATH;
    }
    elsif ( Elevate::OS::bootloader_config_method() eq 'grub-mkconfig' ) {
        return -x UPDATE_GRUB_PATH;
    }
    else {
        LOGDIE("We don't know how to manipulate the bootloader!");
    }
    return;
}

sub _autofix_etc_default_grub ($self) {
    return unless Elevate::OS::needs_grub_enable_blscfg();

    my $etc_default_grub = eval { File::Slurper::read_binary(ETC_DEFAULT_GRUB_PATH) } // '';

    my @lines = split "\n", $etc_default_grub;
    my $found = 0;
    foreach my $line (@lines) {
        next unless $line =~ m/^\s*GRUB_ENABLE_BLSCFG/;
        $found = 1 if $line =~ m/true/;
        $line  = '' unless $found;
        last;
    }

    push @lines, 'GRUB_ENABLE_BLSCFG=true' unless $found;

    @lines = grep { $_ ne '' } @lines;
    my $content = join "\n", @lines;
    $content .= "\n";
    File::Slurper::write_text( ETC_DEFAULT_GRUB_PATH, $content );

    $self->ssystem_and_die( GRUB2_MKCONFIG, '-o', GRUB_CFG ) unless $found;
    return;
}

sub mark_cmdline ($self) {
    return unless _check_command_exists();

    $self->_autofix_etc_default_grub();

    my $arg = "elevate-" . _persistent_id;
    INFO("Marking default boot entry with additional parameter \"$arg\".");

    $self->_add_kernel_arg($arg);

    return;
}

sub _remove_but_dont_stop_service ($self) {

    $self->cpev->service->disable();
    $self->ssystem( '/usr/bin/systemctl', 'daemon-reload' );

    return;
}

# Return true on success, false on failure
sub _remove_kernel_arg ( $self, $arg ) {
    my $result;
    if ( Elevate::OS::bootloader_config_method() eq 'grubby' ) {
        my $kernel_path = $self->_default_kernel;
        $result = !$self->_call_grubby( "--update-kernel=$kernel_path", "--remove-args=$arg" );
    }
    elsif ( Elevate::OS::bootloader_config_method() eq 'grub-mkconfig' ) {
        $result = unlink(GRUB_MKCONFIG_FRAG_FILE_PATH) && !$self->_call_update_grub();
    }
    else {
        LOGDIE("We don't know how to manipulate the bootloader!");
    }
    return $result;
}

sub verify_cmdline ($self) {
    return unless _check_command_exists();
    if ( !$self->cpev->upgrade_distro_manually() ) {
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

        my $result = $self->_remove_kernel_arg($arg);
        WARN("Unable to restore original command line. This should not cause problems but is unusual.") unless $result;

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

            exit Elevate::Constants::EX_UNAVAILABLE();    ## no critic(Cpanel::NoExitsFromSubroutines)
        }
    }

    return;
}

1;
