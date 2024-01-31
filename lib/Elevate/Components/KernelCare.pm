package Elevate::Components::KernelCare;

=encoding utf-8

=head1 NAME

Elevate::Components::KernelCare

Capture and reinstall KernelCare.

=cut

use cPstrict;

use Elevate::Constants ();
use Elevate::OS        ();

use Cwd            ();
use File::Copy     ();
use Log::Log4perl  qw(:easy);
use Elevate::Fetch ();

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    return if Elevate::OS::leapp_can_handle_kernelcare();

    $self->run_once("_remove_kernelcare_if_needed");

    return;
}

sub post_leapp ($self) {

    return if Elevate::OS::leapp_can_handle_kernelcare();

    $self->run_once('_restore_kernelcare');

    return;
}

sub _remove_kernelcare_if_needed ($self) {

    return unless -x q[/usr/bin/kcarectl];

    # This environment variable signals to the KernelCare RPM scriptlets not to deregister on package removal.
    local $ENV{KCARE_KEEP_REGISTRATION} = '1';
    $self->remove_rpms_from_repos('kernelcare');

    cpev::update_stage_file( { 'reinstall' => { 'kernelcare' => 1 } } );

    return 1;
}

sub _restore_kernelcare ($self) {
    return unless cpev::read_stage_file('reinstall')->{'kernelcare'};

    INFO("Restoring kernelcare");

    INFO("Retrieving kernelcare installer");
    my $installer_script = Elevate::Fetch::script( 'https://kernelcare.com/installer', 'kernelcare_installer' );

    my $conf_file = q[/etc/sysconfig/kcare/kcare.conf];
    if ( -e $conf_file . q[.rpmsave] ) {
        INFO("Restoring Configuration file: $conf_file");

        # restore configuration file before installing it
        File::Copy::copy( $conf_file . q[.rpmsave], $conf_file );
    }

    INFO("Running kernelcare installer");
    $self->ssystem_and_die( '/usr/bin/bash' => $installer_script );

    unlink $installer_script;

    INFO("Updating kernelcare");
    $self->ssystem(qw{ /usr/bin/kcarectl --update });

    return;
}

1;
