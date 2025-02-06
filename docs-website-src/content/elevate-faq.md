title: "Troubleshoot the ELevate Process"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

# Troubleshoot the ELevate process

This document provides answers to frequently asked questions and some common troubleshooting issues.

If you need more help, you can <a href="https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/" target="_blank">open a ticket</a>.

## Frequently asked questions

### How do I check the current status of the process

Run the following command to check the current status of the ELevate process:

```
/scripts/elevate-cpanel --status
```

### Where are the current stage and status stored?

They are stored in the `/var/cpanel/elevate` JSON file as values for the
`stage_number` and `status` keys.

During execution the  `stage_number` key will be set to `1` through `5`. When the process completes, the `stage_number` key is set to `6`.

The possible values for `status` key are:

* `running`
* `paused`
* `success`
* `failed`

### Where is the ELevate log file?

You can view the main log from the `/scripts/elevate-cpanel` script with the following command:

```
/scripts/elevate-cpanel --log
```

### Where are leapp issues logged?

Access logs for the leapp process are located in the following files:  

* `/var/log/leapp/leapp-report.txt`
* `/var/log/leapp/leapp-report.json`


### How do I continue the ELevate process if it stops?

Address any reported issues, then continue the existing process with the following command:

```
/scripts/elevate-cpanel --continue
```

## Troubleshooting

### The ELevate process is locked on stage 1

If the elevate process is locked on `stage 1` and the process appears to be looping, run the following command:

```
   /scripts/elevate-cpanel --start
```

You can also unlock the process with the following commands:

1. Clear the previous stage with the following command. Do **not** use this option if the process is past Stage 2.

```
   /scripts/elevate-cpanel --clean
````

2. Restart the ELevate process:
```
   /scripts/elevate-cpanel --start
```

### The CCS service will not start after ELevate succeeds

This error can occur if the scheme failed to update.  

Perform the following steps to correct this error:

**NOTE:** Only remove/install `cpanel-z-push` if it was installed prior to running
elevate or it is currently installed.  Run the following command to check the status of the package:

RHEL-based systems:
```
rpm -q cpanel-z-push
```

Ubuntu-based systems:
```
apt list --installed | grep cpanel-z-push
```

1.  Remove the package:

RHEL-based systems:
```
dnf -y remove cpanel-ccs-calendarserver cpanel-z-push
```

Ubuntu-based systems:
```
apt -y remove cpanel-ccs-calendarserver cpanel-z-push
```

2.  Remove the `cpanel-ccs` user's home directory

```
rm -rf /opt/cpanel-ccs/
```

3.  Install the package(s)

RHEL-based-systems:
```
dnf -y install cpanel-ccs-calendarserver cpanel-z-push
```

Ubuntu-based systems:
```
apt -y install cpanel-ccs-calendarserver cpanel-z-push
```

4.  Clear the `queueprocd` task queue

```
/usr/local/cpanel/bin/servers_queue run
```

5.  Verify that the `cpanel-ccs` service is running with the following command:

```
/scripts/restartsrv_cpanel_ccs --status
```

The output will resemble the following example if the service is running:

```
cpanel-ccs (CalendarServer 9.3+fbd0e11675cc0f64a425581b5c8398cc1e09cb6a [Combined] ) is running as cpanel-ccs with PID 1865839 (systemd+/proc check method)
```

6.  Import the CCS data.


### The CCS data failed to import during elevate

This data is exported to `/var/cpanel/elevate_ccs_export/` directory.

Run the following command as the `root` user to import the data for `every` user:

```
/usr/local/cpanel/3rdparty/bin/perl -MCpanel::Config::Users -e 'require "/var/cpanel/perl5/lib/CCSHooks.pm"; my @users = Cpanel::Config::Users::getcpusers(); foreach my $user (@users) { my $import_data = { user => $user, extract_dir => "/var/cpanel/elevate_ccs_export/$user", }; CCSHooks::pkgacct_restore( undef, $import_data ); }'
```

To import a `single` user, use the command instead, where `CPTEST` represents the username.
```
/usr/local/cpanel/3rdparty/bin/perl -e 'require "/var/cpanel/perl5/lib/CCSHooks.pm"; my $import_data = { user => "CPTEST", extract_dir => "/var/cpanel/elevate_ccs_export/CPTEST", }; CCSHooks::pkgacct_restore( undef, $import_data );'
```
