package Elevate::OS::Ubuntu20;

=encoding utf-8

=head1 NAME

Elevate::OS::Ubuntu20 - Ubuntu20 custom values

=cut

use cPstrict;

use parent 'Elevate::OS::Ubuntu';

# This is intentionally very ridid for the MVP of u20->u22 upgrades
# The key represents the exact name of the file that is supported
# The value represents the contents that the file should contain after the
# upgrade has completed
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
  disabled
  powerdns
};

use constant default_upgrade_to => 'Ubuntu';

use constant ea_alias => 'Ubuntu_22.04';

use constant expected_post_upgrade_major => 22;
use constant is_experimental             => 1;
use constant name                        => 'Ubuntu20';
use constant original_os_major           => 20;
use constant pretty_name                 => 'Ubuntu 20.04';
use constant upgrade_to_pretty_name      => 'Ubuntu 22.04';

1;
