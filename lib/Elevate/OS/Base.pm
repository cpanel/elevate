package Elevate::OS::Base;

=encoding utf-8

=head1 NAME

Elevate::OS::Base

This is a base class currently used by Elevate::OS::*

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use Simple::Accessor qw{
  ea_alias
  elevate_rpm_url
  default_upgrade_to
  leapp_can_handle_epel
  leapp_can_handle_imunify
  leapp_can_handle_kernelcare
  leapp_can_handle_python36
  leapp_data_pkg
  leapp_flag
  name
  pretty_name
  upgrade_to
};

# NOTE: AlmaLinux_8 is just an alias for CentOS_8 so it really doesn't matter
#       which of the two is used
sub _build_ea_alias ($self) {
    return 'CentOS_8';
}

sub _build_elevate_rpm_url ($self) {
    die "subclass must implement elevate_rpm_url\n";
}

sub _build_default_upgrade_to ($self) {
    die "subclass must implement default_upgrade_to\n";
}

sub _build_leapp_can_handle_epel ($self) {
    return 0;
}

sub _build_leapp_can_handle_imunify ($self) {
    return 0;
}

sub _build_leapp_can_handle_kernelcare ($self) {
    return 0;
}

sub _build_leapp_can_handle_python36 ($self) {
    return 0;
}

sub _build_leapp_data_pkg ($self) {
    die "subclass must implement leapp_data_pkg\n";
}

sub _build_name ($self) {
    die "subclass must implement name\n";
}

sub _build_pretty_name ($self) {
    die "subclass must implment pretty_name\n";
}

sub _build_upgrade_to ($self) {
    my $default = $self->default_upgrade_to();
    return cpev::read_stage_file( 'upgrade_to', $default );
}

1;
