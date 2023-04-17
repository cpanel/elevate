package Elevate::Constants;

=encoding utf-8

=head1 NAME

Elevate::Constants

Define some shared constants for the elevate process.

Note: not all constants need to be defined here, it could makes more
sense to isolate some constant in their own component or blocker file,
if their usage is self contained.

=cut

use constant MINIMUM_LTS_SUPPORTED      => 102;
use constant MINIMUM_CENTOS_7_SUPPORTED => 9;

use constant SERVICE_DIR  => '/etc/systemd/system/';
use constant SERVICE_NAME => 'elevate-cpanel.service';

use constant LOG_FILE => q[/var/log/elevate-cpanel.log];
use constant PID_FILE => q[/var/run/elevate-cpanel.pid];

use constant DEFAULT_GRUB_FILE => '/etc/default/grub';

use constant YUM_REPOS_D => q[/etc/yum.repos.d];

1;
