package Elevate::OS::Ubuntu22;

=encoding utf-8

=head1 NAME

Elevate::OS::Ubuntu20 - Ubuntu20 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::Ubuntu';

# The key represents the exact name of the file that is supported
# The value represents the contents that the file should contain after the
# upgrade has completed
use constant vetted_apt_lists => {
    'alt-common-els.list' => q{deb [arch=amd64] https://repo.alt.tuxcare.com/alt-common/deb/ubuntu/24.04/stable noble main},

    'cpanel-plugins.list' => q{deb mirror://httpupdate.cpanel.net/cpanel-plugins-u24-mirrorlist ./},

    'droplet-agent.list' => q{deb [signed-by=/usr/share/keyrings/droplet-agent-keyring.gpg] https://repos-droplet.digitalocean.com/apt/droplet-agent main main},

    'EA4.list' => q{deb mirror://httpupdate.cpanel.net/ea4-u24-mirrorlist ./},

    'imunify-rollout.list' => q{deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-1/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-2/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-3/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-4/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-5/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-6/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-7/ noble main
deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-8/ noble main},

    'imunify360.list' => q{deb [arch=amd64] https://repo.imunify360.cloudlinux.com/imunify360/ubuntu/24.04/ noble main},

    'mariadb.list' => q{deb [arch=amd64,arm64] https://dlm.mariadb.com/repo/mariadb-server/10.11/repo/ubuntu noble main
deb [arch=amd64,arm64] https://dlm.mariadb.com/repo/mariadb-server/10.11/repo/ubuntu noble main/debug},

    'wp-toolkit-cpanel.list' => q{# WP Toolkit
deb [signed-by=/etc/apt/keyrings/wp-toolkit-cpanel.gpg] https://wp-toolkit.plesk.com/cPanel/Ubuntu-24.04-x86_64/latest/wp-toolkit/ ./

# WP Toolkit Thirdparties
deb [signed-by=/etc/apt/keyrings/wp-toolkit-cpanel.gpg] https://wp-toolkit.plesk.com/cPanel/Ubuntu-24.04-x86_64/latest/thirdparty/ ./},

    map { my $thing = $_; "jetapps-$_.list" => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/$_ main" } qw{base plugins alpha beta edge rc release stable},
};

use constant supported_cpanel_mysql_versions => qw{
  8.0
  8.4
  10.11
  11.4
};

use constant archive_dir                      => 'Ubuntu20-to-Ubuntu22';
use constant ea_alias                         => 'xUbuntu_24.04';
use constant expected_post_upgrade_major      => 24;
use constant lts_supported                    => 132;
use constant minimum_supported_cpanel_version => 132;
use constant name                             => 'Ubuntu22';
use constant original_os_major                => 22;
use constant pretty_name                      => 'Ubuntu 22.04';
use constant should_archive_elevate_files     => 1;
use constant upgrade_to_pretty_name           => 'Ubuntu 24.04';

1;
