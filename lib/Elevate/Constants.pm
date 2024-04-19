package Elevate::Constants;

=encoding utf-8

=head1 NAME

Elevate::Constants

Define some shared constants for the elevate process.

Note: not all constants need to be defined here, it could makes more
sense to isolate some constant in their own component or blocker file,
if their usage is self contained.

=cut

use cPstrict;

use constant MINIMUM_LTS_SUPPORTED => 110;
use constant MAXIMUM_LTS_SUPPORTED => 110;

use constant SERVICE_DIR  => '/etc/systemd/system/';
use constant SERVICE_NAME => 'elevate-cpanel.service';

use constant LOG_FILE => q[/var/log/elevate-cpanel.log];
use constant PID_FILE => q[/var/run/elevate-cpanel.pid];

use constant DEFAULT_GRUB_FILE => '/etc/default/grub';

use constant YUM_REPOS_D => q[/etc/yum.repos.d];

use constant ELEVATE_BACKUP_DIR => "/root/.elevate.backup";

use constant IMUNIFY_AGENT => '/usr/bin/imunify360-agent';

1;
