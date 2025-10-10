package Elevate::OS::AlmaLinux8;

=encoding utf-8

=head1 NAME

Elevate::OS::AlmaLinux8 - AlmaLinux8 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::RHEL';

use constant supported_cpanel_mysql_versions => qw{
  8.0
  8.4
  10.5
  10.6
  10.11
  11.4
};

use constant archive_dir                  => 'CentOS7-to-AlmaLinux8';
use constant ea_alias                     => 'CentOS_9';
use constant el_package_regex             => 'el8';
use constant elevate_rpm_url              => 'https://repo.almalinux.org/elevate/elevate-release-latest-el8.noarch.rpm';
use constant has_imunify_ea_alias         => 1;
use constant imunify_ea_alias             => 'CloudLinux_9';
use constant expected_post_upgrade_major  => 9;
use constant jetbackup_repo_rpm_url       => 'https://repo.jetlicense.com/centOS/jetapps-repo-4096-latest.rpm';
use constant name                         => 'AlmaLinux8';
use constant needs_crb                    => 1;
use constant needs_grub_enable_blscfg     => 1;
use constant needs_network_manager        => 1;
use constant needs_sha1_enabled           => 1;
use constant needs_type_in_ifcfg          => 1;
use constant needs_vdo                    => 1;
use constant original_os_major            => 8;
use constant pretty_name                  => 'AlmaLinux 8';
use constant should_archive_elevate_files => 1;
use constant supports_named_tiers         => 1;
use constant upgrade_to_pretty_name       => 'AlmaLinux 9';

sub vetted_yum_repo ($self) {
    my @repos = $self->SUPER::vetted_yum_repo();
    push @repos, $self->vetted_mysql_yum_repo_ids();
    push @repos, 'powertools', 'appstream';
    return @repos;
}

sub vetted_mysql_yum_repo_ids ($self) {

    # No use doing this since we have to call this sub directly via
    # Elevate::OS::vetted_yum_repo() anyway
    # my @repos = $self->SUPER::vetted_mysql_yum_repo_ids();

    return (
        qr/^mysql-[0-9]\.[0-9]-lts-community$/,
        qr/^mysql-(?:tools|cluster)-[0-9]\.[0-9]-lts-community$/,
    );
}

1;
