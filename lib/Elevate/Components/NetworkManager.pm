package Elevate::Components::NetworkManager;

=encoding utf-8

=head1 NAME

Elevate::Components::NetworkManager

=head2 check

noop

=head2 pre_distro_upgrade

Enable the NetworkManager service so that it will start on the next reboot

=head2 post_distro_upgrade

noop

=cut

use cPstrict;

use Elevate::OS               ();
use Elevate::SystemctlService ();

use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_distro_upgrade ($self) {
    return if $self->upgrade_distro_manually();    # skip when --upgrade-distro-manually is provided
    return unless Elevate::OS::needs_network_manager();

    my $service_name = 'NetworkManager';
    my $service      = Elevate::SystemctlService->new( name => $service_name );

    return if $service->is_enabled();
    $service->enable();
    return;
}

1;
