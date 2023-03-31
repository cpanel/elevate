package Elevate::Constants;

use constant MINIMUM_LTS_SUPPORTED      => 102;
use constant MINIMUM_CENTOS_7_SUPPORTED => 9;

use constant SERVICE_DIR  => '/etc/systemd/system/';
use constant SERVICE_NAME => 'elevate-cpanel.service';

use constant LOG_FILE => q[/var/log/elevate-cpanel.log];
use constant PID_FILE => q[/var/run/elevate-cpanel.pid];

use constant DEFAULT_GRUB_FILE => '/etc/default/grub';

use constant YUM_REPOS_D => q[/etc/yum.repos.d];

1;
