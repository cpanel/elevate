package Elevate::OS::CloudLinux;

=encoding utf-8

=head1 NAME

Elevate::OS::CloudLinux - CloudLinux base class

=cut

use cPstrict;

use parent 'Elevate::OS::RHEL';

use constant default_upgrade_to              => 'CloudLinux';
use constant leapp_repo_prod                 => 'cloudlinux-elevate';
use constant leapp_repo_beta                 => 'cloudlinux-elevate-updates-testing';
use constant leapp_can_handle_imunify        => 1;
use constant leapp_can_handle_kernelcare     => 1;
use constant leapp_data_pkg                  => 'leapp-data-cloudlinux';
use constant leapp_flag                      => '--nowarn';
use constant name                            => 'CloudLinux';
use constant pretty_name                     => 'CloudLinux';
use constant provides_mysql_governor         => 1;
use constant should_check_cloudlinux_license => 1;

sub vetted_yum_repo ($self) {
    my @vetted_cloudlinux_yum_repo = (
        qr/^cloudlinux(?:-(?:base|updates|extras|compat|imunify360|elevate))?$/,
        qr/^cloudlinux-rollout(?:-[0-9]+)?$/,
        qr/^cloudlinux-ea4(?:-[0-9]+)?$/,
        qr/^cloudlinux-ea4-rollout(?:-[0-9]+)?$/,
        'cl-ea4',
        qr/^cl-mysql(?:-meta)?/,
        'mysqclient', 'mysql-debuginfo',
        'cl7h',
        qr/^repo\.cloudlinux\.com_/,
    );

    my @repos = $self->SUPER::vetted_yum_repo();
    push @repos, @vetted_cloudlinux_yum_repo;
    return @repos;
}

1;
