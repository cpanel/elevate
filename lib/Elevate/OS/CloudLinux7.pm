package Elevate::OS::CloudLinux7;

=encoding utf-8

=head1 NAME

Elevate::OS::CloudLinux7 - CloudLinux7 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::RHEL';

use constant supported_cpanel_mysql_versions => qw{
  8.0
  10.3
  10.4
  10.5
  10.6
  10.11
  11.4
};

use constant default_upgrade_to              => 'CloudLinux';
use constant ea_alias                        => 'CloudLinux_8';
use constant el_package_regex                => 'el7';
use constant elevate_rpm_url                 => 'https://repo.cloudlinux.com/elevate/elevate-release-latest-el7.noarch.rpm';
use constant expected_post_upgrade_major     => 8;
use constant leapp_repo_prod                 => 'cloudlinux-elevate';
use constant leapp_repo_beta                 => 'cloudlinux-elevate-updates-testing';
use constant leapp_can_handle_imunify        => 1;
use constant leapp_can_handle_kernelcare     => 1;
use constant leapp_data_pkg                  => 'leapp-data-cloudlinux';
use constant leapp_flag                      => '--nowarn';
use constant lts_supported                   => 110;
use constant name                            => 'CloudLinux7';
use constant needs_powertools                => 1;
use constant original_os_major               => 7;
use constant pkgmgr_lib_path                 => '/var/lib/yum';
use constant pretty_name                     => 'CloudLinux 7';
use constant provides_mysql_governor         => 1;
use constant should_check_cloudlinux_license => 1;
use constant upgrade_to_pretty_name          => 'CloudLinux 8';

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
    );

    my @repos = $self->SUPER::vetted_yum_repo();
    push @repos, @vetted_cloudlinux_yum_repo;
    return @repos;
}

1;
