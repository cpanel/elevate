package Elevate::OS::Ubuntu;

=encoding utf-8

=head1 NAME

Elevate::OS::Ubuntu

ubuntu base class

=cut

use cPstrict;

use Log::Log4perl qw(:easy);

use constant vetted_apt_lists => {
    'cpanel-plugins.list' => q{deb mirror://httpupdate.cpanel.net/cpanel-plugins-u22-mirrorlist ./},

    'droplet-agent.list' => q{deb [signed-by=/usr/share/keyrings/droplet-agent-keyring.gpg] https://repos-droplet.digitalocean.com/apt/droplet-agent main main},

    'EA4.list' => q{deb mirror://httpupdate.cpanel.net/ea4-u22-mirrorlist ./},

    'imunify-rollout.list' => q{deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-1/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-2/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-3/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-4/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-5/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-6/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-7/ jammy main
deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-8/ jammy main},

    'imunify360.list' => q{deb [arch=amd64] https://repo.imunify360.cloudlinux.com/imunify360/ubuntu/22.04/ jammy main'},

    'mysql.list' => q{# Use command 'dpkg-reconfigure mysql-apt-config' as root for modifications.
deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-apt-config
deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-8.0
deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-tools
#deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-tools-preview
deb-src https://repo.mysql.com/apt/ubuntu/ jammy mysql-8.0},

    'wp-toolkit-cpanel.list' => q{# WP Toolkit
deb https://wp-toolkit.plesk.com/cPanel/Ubuntu-22.04-x86_64/latest/wp-toolkit/ ./

# WP Toolkit Thirdparties
deb https://wp-toolkit.plesk.com/cPanel/Ubuntu-22.04-x86_64/latest/thirdparty/ ./},
};

use constant supported_cpanel_mysql_versions => qw{
  8.0
  10.6
  10.11
};

use constant supported_cpanel_nameserver_types => qw{
  powerdns
};

use constant default_upgrade_to              => undef;
use constant ea_alias                        => undef;
use constant is_apt_based                    => 1;
use constant is_supported                    => 1;
use constant lts_supported                   => 118;
use constant name                            => 'Ubuntu';
use constant needs_do_release_upgrade        => 1;
use constant needs_leapp                     => 0;
use constant pretty_name                     => 'Ubuntu';
use constant provides_mysql_governor         => 0;
use constant remove_els                      => 0;
use constant should_check_cloudlinux_license => 0;
use constant skip_minor_version_check        => 1;
use constant supports_jetbackup              => 0;
use constant supports_kernelcare             => 0;
use constant supports_postgresql             => 0;

1;
