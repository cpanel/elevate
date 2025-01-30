title: "Troubleshoot the ELevate Process"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

## Troubleshoot the ELevate process

This document provides some tips  and a

If you need more help, you can [open a ticket](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/).

### Check the current status of the process

You can check the current status of the elevation process by running:
```
/scripts/elevate-cpanel --status
```

### Where are the current stage and status stored?

They are stored in the JSON file `/var/cpanel/elevate` as values for the
`stage_number` and `status` keys.

During execution `stage_number` will be set to `1` through `5`. Upon
completion the `stage_number` will be set to `6`.

The possible values for `status` are:

* `running`
* `paused`
* `success`
* `failed`

### How to check elevate log?

The main log from the `/scripts/elevate-cpanel` can be read by running:
```
/scripts/elevate-cpanel --log
```

### Where to find leapp issues?

If you need more details why the leapp process failed you can access logs at:
```
        /var/log/leapp/leapp-report.txt
        /var/log/leapp/leapp-report.json
```

### How to continue the elevation process?

After addressing the reported issues, you can continue an existing elevation process by running:
```
/scripts/elevate-cpanel --continue
```

### The elevate process is locked on stage 1

If you notice that the elevate process is locked on `stage 1` and you are looping
on the advice:
```
You can consider running:
   /scripts/elevate-cpanel --start
```

You can unlock the situation by using the `--clean` option.
```
# clean the previous state (do not run when an elevation process passed stage 2 or more)
   /scripts/elevate-cpanel --clean

# then restart the process
   /scripts/elevate-cpanel --start
```

### The CCS service will not start after elevate succeeds

This can sometimes occur due to a failed schema update.  When this occurs, we
recommend that you complete the following steps:

1. Remove the CCS package(s),
2. Remove the home directory for the packages user,
3. Reinstall the package,
4. Finally, ensure that the task queue completes before continuing

**NOTE:** Only remove/install cpanel-z-push if it was installed prior to running
elevate / is currently installed.  You can check if it is installed with the
following command:

```
rpm -q cpanel-z-push
```

1.  Remove the package(s)
```
dnf -y remove cpanel-ccs-calendarserver cpanel-z-push
```

2.  Remove the `cpanel-ccs` user's home directory
```
rm -rf /opt/cpanel-ccs/
```

3.  Install the package(s)
```
dnf -y install cpanel-ccs-calendarserver cpanel-z-push
```

4.  Clear the queueprocd task queue
```
/usr/local/cpanel/bin/servers_queue run
```

5.  Verify that the cpanel-ccs service is running
```
/scripts/restartsrv_cpanel_ccs --status
```

The output should be similar to the following if the service is up:
```
cpanel-ccs (CalendarServer 9.3+fbd0e11675cc0f64a425581b5c8398cc1e09cb6a [Combined] ) is running as cpanel-ccs with PID 1865839 (systemd+/proc check method)
```

6.  Import the CCS data

### The CCS data failed to import during elevate

This data is exported to `/var/cpanel/elevate_ccs_export/`.

Executing the following Perl one-liner as root will import the data for each user:
```
/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Config::Users -e 'require "/var/cpanel/perl5/lib/CCSHooks.pm"; my @users = Cpanel::Config::Users::getcpusers(); foreach my $user (@users) { my $import_data = { user => $user, extract_dir => "/var/cpanel/elevate_ccs_export/$user", }; CCSHooks::pkgacct_restore( undef, $import_data ); }'
```

To import a single user, use the following one-liner instead:
```
/usr/local/cpanel/3rdparty/bin/perl -e 'require "/var/cpanel/perl5/lib/CCSHooks.pm"; my $import_data = { user => "CPTEST", extract_dir => "/var/cpanel/elevate_ccs_export/CPTEST", }; CCSHooks::pkgacct_restore( undef, $import_data );'
```

**NOTE:**  The above example uses `cptest` as the user.  Replace `cptest` with
the appropriate username for the user that you wish to import.
