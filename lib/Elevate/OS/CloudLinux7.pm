package Elevate::OS::CloudLinux7;

=encoding utf-8

=head1 NAME

Elevate::OS::CloudLinux7 - CloudLinux7 custom values

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use parent 'Elevate::OS::Base';

sub _build_ea_alias ($self) {
    return 'CloudLinux_8';
}

sub _build_elevate_rpm_url ($self) {
    return 'https://repo.cloudlinux.com/elevate/elevate-release-latest-el7.noarch.rpm';
}

sub _build_default_upgrade_to ($self) {
    return 'CloudLinux';
}

sub _build_leapp_can_handle_epel ($self) {
    return 1;
}

sub _build_leapp_can_handle_imunify ($self) {
    return 1;
}

sub _build_leapp_can_handle_kernelcare ($self) {
    return 1;
}

sub _build_leapp_can_handle_python36 ($self) {
    return 1;
}

sub _build_leapp_data_pkg ($self) {
    return 'leapp-data-cloudlinux';
}

sub _build_leapp_flag ($self) {
    return '--nowarn';
}

sub _build_name ($self) {
    return 'CloudLinux7';
}

sub _build_pretty_name ($self) {
    return 'CloudLinux 7';
}

1;
