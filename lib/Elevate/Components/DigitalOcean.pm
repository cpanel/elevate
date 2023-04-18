package Elevate::Components::DigitalOcean;

=encoding utf-8

=head1 NAME

Elevate::Components::DigitalOcean

Restore Digital Ocean agent

=cut

use cPstrict;

use Cpanel::Pkgr       ();
use Elevate::Constants ();

use Cwd           ();
use Log::Log4perl qw(:easy);

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    # nothing

    return;
}

sub post_leapp ($self) {

    # reinstall_digital_ocean_droplet_agent

    return unless Cpanel::Pkgr::is_installed('droplet-agent');
    return unless -f '/etc/yum.repos.d/droplet-agent.repo';

    $self->ssystem(qw{/usr/bin/yum -y reinstall droplet-agent});

    return;
}

1;
