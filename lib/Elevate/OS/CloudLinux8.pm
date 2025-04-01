package Elevate::OS::CloudLinux8;

=encoding utf-8

=head1 NAME

Elevate::OS::CloudLinux8 - CloudLinux8 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::CloudLinux';

use constant supported_cpanel_mysql_versions => qw{
  8.0
  10.5
  10.6
  10.11
  11.4
};

use constant archive_dir                  => 'CloudLinux7-to-CloudLinux8';
use constant ea_alias                     => 'CloudLinux_9';
use constant el_package_regex             => 'el8';
use constant elevate_rpm_url              => 'https://repo.cloudlinux.com/elevate/elevate-release-latest-el8.noarch.rpm';
use constant expected_post_upgrade_major  => 9;
use constant is_experimental              => 1;
use constant jetbackup_repo_rpm_url       => 'https://repo.jetlicense.com/centOS/jetapps-repo-4096-latest.rpm';
use constant lts_supported                => 126;
use constant name                         => 'CloudLinux8';
use constant needs_crb                    => 1;
use constant needs_grub_enable_blscfg     => 1;
use constant needs_network_manager        => 1;
use constant needs_sha1_enabled           => 1;
use constant needs_vdo                    => 1;
use constant original_os_major            => 8;
use constant pkgmgr_lib_path              => '/var/lib/dnf';
use constant pretty_name                  => 'CloudLinux 8';
use constant should_archive_elevate_files => 1;
use constant upgrade_to_pretty_name       => 'CloudLinux 9';

sub vetted_yum_repo ($self) {
    my @repos = $self->SUPER::vetted_yum_repo();
    push @repos, 'powertools', 'appstream';
    return @repos;
}

1;
