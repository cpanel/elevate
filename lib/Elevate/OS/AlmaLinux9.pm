package Elevate::OS::AlmaLinux9;

=encoding utf-8

=head1 NAME

Elevate::OS::AlmaLinux9 - AlmaLinux9 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::RHEL';

use constant supported_cpanel_mysql_versions => qw{
  8.4
  10.11
  11.4
};

use constant archive_dir                      => 'AlmaLinux8-to-AlmaLinux9';
use constant ea_alias                         => 'Almalinux_10';
use constant el_package_regex                 => 'el9';
use constant elevate_rpm_url                  => 'https://repo.almalinux.org/elevate/elevate-release-latest-el9.noarch.rpm';
use constant expected_post_upgrade_major      => 10;
use constant is_experimental                  => 1;
use constant minimum_supported_cpanel_version => 132;
use constant name                             => 'AlmaLinux9';
use constant needs_crb                        => 1;
use constant needs_grub_enable_blscfg         => 1;
use constant needs_network_manager            => 1;
use constant needs_sha1_enabled               => 1;
use constant needs_type_in_ifcfg              => 1;
use constant needs_vdo                        => 1;
use constant network_scripts_are_supported    => 0;
use constant original_os_major                => 9;
use constant os_provides_sha1_module          => 0;
use constant pretty_name                      => 'AlmaLinux 9';
use constant should_archive_elevate_files     => 1;
use constant supports_cpaddons                => 0;
use constant supports_jetbackup               => 0;
use constant supports_kernelcare              => 0;
use constant supports_named_tiers             => 1;
use constant upgrade_to_pretty_name           => 'AlmaLinux 10';

sub vetted_yum_repo ($self) {
    my @repos = $self->SUPER::vetted_yum_repo();
    push @repos, $self->vetted_mysql_yum_repo_ids();
    push @repos, 'appstream';

    # cPAddons is no longer supported on A10
    @repos = grep { $_ ne 'cpanel-addons-production-feed' } @repos;

    return @repos;
}

1;
