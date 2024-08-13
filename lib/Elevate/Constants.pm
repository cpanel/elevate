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

use constant SERVICE_DIR  => '/etc/systemd/system/';
use constant SERVICE_NAME => 'elevate-cpanel.service';

use constant LOG_FILE => q[/var/log/elevate-cpanel.log];
use constant PID_FILE => q[/var/run/elevate-cpanel.pid];

use constant DEFAULT_GRUB_FILE => '/etc/default/grub';

use constant YUM_REPOS_D => q[/etc/yum.repos.d];

use constant ELEVATE_BACKUP_DIR => "/root/.elevate.backup";

use constant IMUNIFY_AGENT => '/usr/bin/imunify360-agent';

use constant CHKSRVD_SUSPEND_FILE => q[/var/run/chkservd.suspend];

use constant IGNORE_OUTDATED_SERVICES_FILE => q[/etc/cpanel/local/ignore_outdated_services];

use constant SBIN_IP => q[/sbin/ip];

use constant ETH_FILE_PREFIX => q[/etc/sysconfig/network-scripts/ifcfg-];

use constant R1SOFT_REPO               => 'r1soft';
use constant R1SOFT_REPO_FILE          => '/etc/yum.repos.d/r1soft.repo';
use constant R1SOFT_MAIN_AGENT_PACKAGE => 'serverbackup-agent';
use constant R1SOFT_AGENT_PACKAGES => qw{
  r1soft-getmodule
  serverbackup-agent
  serverbackup-async-agent-2-6
  serverbackup-enterprise-agent
  serverbackup-setup
};

1;
