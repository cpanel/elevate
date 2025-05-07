package Elevate::OS::RHEL;

=encoding utf-8

=head1 NAME

Elevate::OS::RHEL

Rhel base class

=cut

use cPstrict;

use constant disable_mysql_yum_repos => qw{
  Mysql57.repo
  Mysql80.repo

  MariaDB102.repo
  MariaDB103.repo
  MariaDB105.repo
  MariaDB106.repo

  mysql-community.repo
};

use constant vetted_mysql_yum_repo_ids => (
    qr/^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$/,
    qr/^mysql-connectors-community(?:-(?:source|debuginfo))?$/,
    qr/^mysql-tools-community(?:-(?:source|debuginfo))?$/,
    qr/^mysql-tools-preview(?:-source)?$/,
    qr/^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$/,
    qr/^MariaDB[0-9]+$/,
);

use constant vetted_yum_repo => (
    'base',
    'c7-media',
    qr/^centos-kernel(?:-experimental)?$/,
    'centosplus',
    'cp-dev-tools',
    'cpanel-addons-production-feed',
    'cpanel-plugins',
    'cr',
    'ct-preset',
    'digitalocean-agent',
    'droplet-agent',
    qr/^EA4(?:-c\$releasever)?$/,
    qr/^elasticsearch(?:7\.x)?$/,
    qr/^elevate(?:-source)?$/,
    qr/^epel(?:-testing)?$/,
    'extras',
    'fasttrack',
    'imunify360',
    'imunify360-ea-php-hardened',
    qr/^imunify360-rollout-[0-9]+$/,
    'influxdata',
    'influxdb',
    'jetapps',
    qr/^jetapps-(?:stable|beta|edge)$/,
    'kernelcare',
    qr/^ul($|_)/,
    'hgdedi',
    'updates',
    'r1soft',
    qr/^panopta(?:\.repo)?$/,
    qr/^fortimonitor(?:\.repo)?$/,
    qr/^wp-toolkit-(?:cpanel|thirdparties)$/,
    'platform360-cpanel',
  ),
  vetted_mysql_yum_repo_ids;

use constant supported_cpanel_nameserver_types => qw{
  bind
  disabled
  powerdns
};

use constant archive_dir                     => undef;
use constant bootloader_config_method        => 'grubby';
use constant default_upgrade_to              => undef;
use constant ea_alias                        => undef;
use constant el_package_regex                => undef;
use constant elevate_rpm_url                 => undef;
use constant expected_post_upgrade_major     => undef;
use constant has_crypto_policies             => 1;
use constant has_imunify_ea_alias            => 0;
use constant imunify_ea_alias                => undef;
use constant is_apt_based                    => 0;
use constant is_experimental                 => 0;
use constant is_supported                    => 1;
use constant jetbackup_repo_rpm_url          => undef;
use constant leapp_can_handle_imunify        => 0;
use constant leapp_can_handle_kernelcare     => 0;
use constant leapp_data_pkg                  => undef;
use constant leapp_flag                      => undef;
use constant leapp_repo_beta                 => '';
use constant leapp_repo_prod                 => 'elevate';
use constant lts_supported                   => undef;
use constant name                            => 'RHEL';
use constant needs_crb                       => 0;
use constant needs_do_release_upgrade        => 0;
use constant needs_epel                      => 1;
use constant needs_grub_enable_blscfg        => 0;
use constant needs_leapp                     => 1;
use constant needs_network_manager           => 0;
use constant needs_powertools                => 0;
use constant needs_sha1_enabled              => 0;
use constant needs_vdo                       => 0;
use constant package_manager                 => 'YUM';
use constant pkgmgr_lib_path                 => undef;
use constant pretty_name                     => 'RHEL';
use constant provides_mysql_governor         => 0;
use constant remove_els                      => 0;
use constant should_archive_elevate_files    => 0;
use constant should_check_cloudlinux_license => 0;
use constant skip_minor_version_check        => 0;
use constant supported_cpanel_mysql_versions => undef;
use constant supports_jetbackup              => 1;
use constant supports_kernelcare             => 1;
use constant supports_named_tiers            => 0;
use constant supports_postgresql             => 1;
use constant upgrade_to_pretty_name          => undef;
use constant vetted_apt_lists                => {};
use constant yum_conf_needs_plugins          => 0;

1;
