package Elevate::OS::CloudLinux7;

=encoding utf-8

=head1 NAME

Elevate::OS::CloudLinux7 - CloudLinux7 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::CloudLinux';

use constant supported_cpanel_mysql_versions => qw{
  8.0
  10.3
  10.4
  10.5
  10.6
  10.11
  11.4
};

use constant ea_alias                    => 'CloudLinux_8';
use constant el_package_regex            => 'el7';
use constant elevate_rpm_url             => 'https://repo.cloudlinux.com/elevate/elevate-release-latest-el7.noarch.rpm';
use constant expected_post_upgrade_major => 8;
use constant has_crypto_policies         => 0;
use constant lts_supported               => 110;
use constant name                        => 'CloudLinux7';
use constant needs_powertools            => 1;
use constant original_os_major           => 7;
use constant pkgmgr_lib_path             => '/var/lib/yum';
use constant pretty_name                 => 'CloudLinux 7';
use constant upgrade_to_pretty_name      => 'CloudLinux 8';

1;
