package Elevate::OS::RHEL;

=encoding utf-8

=head1 NAME

Elevate::OS::RHEL

Rhel base class

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

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
    qr/^MariaDB[0-9]{3}$/,
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
    'influxdb',
    'jetapps',
    qr/^jetapps-(?:stable|beta|edge)$/,
    'kernelcare',
    'updates',
    'r1soft',
    qr/^wp-toolkit-(?:cpanel|thirdparties)$/,
  ),
  vetted_mysql_yum_repo_ids;

use constant default_upgrade_to              => undef;
use constant ea_alias                        => undef;
use constant elevate_rpm_url                 => undef;
use constant is_supported                    => 1;
use constant leapp_can_handle_imunify        => 0;
use constant leapp_can_handle_kernelcare     => 0;
use constant leapp_data_package              => undef;
use constant leapp_flag                      => undef;
use constant name                            => 'RHEL';
use constant pretty_name                     => 'RHEL';
use constant provides_mysql_governor         => 0;
use constant remove_els                      => 0;
use constant should_check_cloudlinux_license => 0;
use constant leapp_repo_beta                 => '';       # Unavailable by default.

1;
