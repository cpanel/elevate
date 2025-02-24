package Elevate::OS::Ubuntu;

=encoding utf-8

=head1 NAME

Elevate::OS::Ubuntu

ubuntu base class

=cut

use cPstrict;

use constant supported_cpanel_nameserver_types => qw{
  disabled
  powerdns
};

use constant archive_dir                     => undef;
use constant bootloader_config_method        => 'grub-mkconfig';
use constant default_upgrade_to              => undef;
use constant disable_mysql_yum_repos         => undef;
use constant ea_alias                        => undef;
use constant el_package_regex                => undef;
use constant elevate_rpm_url                 => undef;
use constant is_apt_based                    => 1;
use constant is_experimental                 => 0;
use constant is_supported                    => 1;
use constant leapp_can_handle_imunify        => undef;
use constant leapp_can_handle_kernelcare     => undef;
use constant leapp_data_pkg                  => undef;
use constant leapp_flag                      => undef;
use constant leapp_repo_beta                 => undef;
use constant leapp_repo_prod                 => undef;
use constant lts_supported                   => 118;
use constant name                            => 'Ubuntu';
use constant needs_crb                       => 0;
use constant needs_do_release_upgrade        => 1;
use constant needs_epel                      => 0;
use constant needs_grub_enable_blscfg        => 0;
use constant needs_leapp                     => 0;
use constant needs_network_manager           => 0;
use constant needs_powertools                => 0;
use constant package_manager                 => 'APT';
use constant pkgmgr_lib_path                 => undef;
use constant pretty_name                     => 'Ubuntu';
use constant provides_mysql_governor         => 0;
use constant remove_els                      => 0;
use constant should_archive_elevate_files    => 0;
use constant should_check_cloudlinux_license => 0;
use constant skip_minor_version_check        => 1;
use constant supported_cpanel_mysql_versions => undef;
use constant supports_jetbackup              => 0;
use constant supports_kernelcare             => 0;
use constant supports_postgresql             => 0;
use constant upgrade_to_pretty_name          => undef;
use constant vetted_yum_repo                 => undef;

1;
