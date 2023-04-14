package Elevate::Constants;

use constant SERVICE_DIR  => '/etc/systemd/system/';
use constant SERVICE_NAME => 'elevate-cpanel.service';

use constant LOG_FILE => q[/var/log/elevate-cpanel.log];
use constant PID_FILE => q[/var/run/elevate-cpanel.pid];

1;
