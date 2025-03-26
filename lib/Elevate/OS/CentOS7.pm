package Elevate::OS::CentOS7;

=encoding utf-8

=head1 NAME

Elevate::OS::CentOS7 - CentOS7 custom values

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

use constant default_upgrade_to          => 'AlmaLinux';
use constant ea_alias                    => 'CentOS_8';
use constant el_package_regex            => 'el7';
use constant elevate_rpm_url             => 'https://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm';
use constant expected_post_upgrade_major => 8;
use constant has_imunify_ea_alias        => 1;
use constant imunify_ea_alias            => 'CloudLinux_8';
use constant leapp_data_pkg              => 'leapp-data-almalinux';
use constant lts_supported               => 110;
use constant name                        => 'CentOS7';
use constant needs_powertools            => 1;
use constant original_os_major           => 7;
use constant pkgmgr_lib_path             => '/var/lib/yum';
use constant pretty_name                 => 'CentOS 7';
use constant remove_els                  => 1;
use constant upgrade_to_pretty_name      => 'AlmaLinux 8';

sub vetted_yum_repo ($self) {

    my @repos = $self->SUPER::vetted_yum_repo();

    # A component uninstalls this repo on CentOS 7, no need to block on it
    push @repos, qr/centos7[-]*els(-rollout-[0-9]+|)/;
    return @repos;
}

1;
