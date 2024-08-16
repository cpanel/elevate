package Elevate::Components::UpdateSystem;

=encoding utf-8

=head1 NAME

Elevate::Components::UpdateSystem

Ensure that all system packages are up to date

=cut

use cPstrict;

use Elevate::OS ();

use parent qw{Elevate::Components::Base};

sub pre_leapp ($self) {

    Elevate::OS::is_apt_based() ? $self->_update_apt() : $self->_update_yum();

    return;
}

sub _update_apt ($self) {
    $self->ssystem_and_die(qw{/scripts/update-packages});
    $self->apt->upgrade_all();
    return;
}

sub _update_yum ($self) {
    $self->ssystem(qw{/usr/bin/yum clean all});
    $self->ssystem_and_die(qw{/scripts/update-packages});
    $self->ssystem_and_die(qw{/usr/bin/yum -y update});
    return;
}

sub post_leapp ($self) {

    # Nothing to do
    return;
}

1;
