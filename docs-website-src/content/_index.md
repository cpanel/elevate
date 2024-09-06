---
title: "cPanel ELevate CentOS 7 to AlmaLinux 8"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

# Welcome to the cPanel ELevate Project!

Read more from the [Elevate website](https://cpanel.github.io/elevate/).

## Goal

The cPanel ELevate Project provides a script to upgrade an existing `cPanel & WHM` RHEL 7 based server installation to a RHEL 8 based installation.

For example:

1.  CentOS 7 to AlmaLinux 8
2.  CloudLinux 7 to CloudLinux 8

[![Intro video to Elevate](elevate-video.png)](https://www.youtube.com/watch?v=Ag9-RneFqmc)


## Disclaimer

We do not guarantee the functionality of software in this repository. You assume all risk for use of any software that you install from this repository. Installation of this software could cause significant functionality failures, even for experienced administrators.

That said, cPanel Technical Support is ready to help!
Please contact [cPanel Technical Support](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/) if you encounter problems.

## Introduction

- [Pull requests are welcome](https://github.com/cpanel/elevate/pulls)
    - Code contributions are subject to our [Contributor License Agreement](docs/cPanel-CLA.pdf)

This project builds on the [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project, which leans heavily on the [LEAPP Project](https://leapp.readthedocs.io/en/latest/) created for in-place upgrades of RedHat-based systems.

The [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project is very effective at upgrading the distro packages. However, if you attempt use it directly on a RHEL 7-based [cPanel&nbsp;install](https://cpanel.net/), you will end up with a broken system.

This project was designed to be a wrapper around the [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project to allow you to successfully upgrade a [cPanel install](https://cpanel.net/) with an aim to minimize outages.

### Our current approach can be summarized as:

1. [Check for blockers](https://cpanel.github.io/elevate/blockers/)
2. `yum update && reboot`
3. Analyze and remove software (not data) commonly installed on a cPanel system
4. [Execute AlmaLinux upgrade](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html)
5. Re-install previously removed software detected prior to upgrade. This might include:
  * cPanel (upcp)
  * EA4
  * MySQL variants
  * Distro Perl/PECL binary re-installs
6. Final reboot (assure all services are running on new binaries)

## Risks

As always, upgrades can lead to data loss or behavior changes that may leave you with a broken system.

Failure states include but are not limited to:

* Failure to upgrade the kernel due to custom drivers
* Incomplete upgrade of software because this code base is not aware of it.

We recommend you back up (and ideally snapshot) your system so it can be easily restored before continuing.

This upgrade will potentially take 30-90 minutes to upgrade all of the software. During most of this time, the server will be degraded and non-functional. We attempt to disable most of the software so that external systems will re-try later rather than fail in an unexpected way. However there are small windows where the unexpected failures leading to some data loss may occur.

## Before updating

Before updating, please check that you met all the pre requirements:

* You will need some kind of interactive shell access as the root user.
  * Having more than one form available is **strongly** recommended, in case a problem during the upgrade prevents use of the primary access method.
  * Examples of acceptable forms of access include:
    * root SSH access to the system itself,
    * direct physical console access,
    * IPMI remote console access,
    * access to the virtual console through the hypervisor, or
    * use of a custom system which is based on one of these methods and is made available by your server provider.
* You should back up your server before attempting this upgrade. The upgrade process tries to detect conditions which will result in a broken system should the process proceed, but this is not perfect.
  * We strongly recommend that this backup take the form of a whole-system image or snapshot.
    * Recovery in this case consists of reloading the system from that image or snapshot.
  * Backups only in the form of individual cPanel accounts will protect data managed by cPanel. These backups **will not** protect programs or data not managed by cPanel or allow you to minimize downtime in case of catastrophic failure which results from the upgrade process. The cPanel Backup system backs up individual cPanel accounts.
    * Recovery in this case consists of wiping the existing system, installing the target operating system, installing cPanel on the new operating system, rebuilding all system customizations in a way that is compatible with the new operating system, and restoring the cPanel accounts from the backup.
    * If individual cPanel account backups are your only backup option, and uptime is a critical consideration, we recommend performing a migration to a new system using the [Transfer Tool](https://docs.cpanel.net/whm/transfers/transfer-tool/) instead of upgrading in-place using ELevate, as this will give you more control over the transition in the event of a failure.
  * If you do not know how much of your system your backup service covers, contact the provider of that service for further information.
* Ensure your server is up to date: `yum update`
* Ensure you are using the last stable version of cPanel & WHM.
* Use a version of MySQL/MariaDB compliant with the target distribution.
* [Write down the information needed to open a support request with cPanel](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/#support-request-requirements) in case of issues during the upgrade process, since this informaton may become unavailable from the system itself.

Additional checks can be performed by [downloading the script](#download-the-elevate-cpanel-script)
and then [running pre-checks](#pre-upgrade-checks).

### Some of the problems you might find include:

* x86_64 RPMs not in the primary CentOS repos are upgraded.
  * `rpm -qa|grep el7`
* EA4 RPMs are incorrect
  * EA4 provides different dependencies and linkage on C7/A8 and CL7/CL8
* cPanel binaries (cpanelsync) are invalid.
* 3rdparty repo packages are not upgraded (imunify 360, epel, ...).
* Manually installed Perl XS (arch) CPAN installs invalid.
* Manually installed PECL need re-build.
* Cpanel::CachedCommand is wrong.
* Cpanel::OS distro setting is wrong.
* MySQL might now not be upgradable (MySQL versions < 8.0 are not normally present on A8).
* The `nobody` user does not switch from UID 99 to UID 65534 even after upgrading to A8.
* The cPanel CCS service may not start.

## Using the script

### Download the elevate-cpanel script

* You can download a copy of the script to run on your cPanel server via:

```bash
wget -O /scripts/elevate-cpanel \
    https://raw.githubusercontent.com/cpanel/elevate/release/elevate-cpanel ;
chmod 700 /scripts/elevate-cpanel
```

### Pre-upgrade checks

We recommend you check for known blockers before you upgrade. The check is designed to not make any changes to your system.

You can check if your system is ready to upgrade by running:
```bash
# Check upgrade (dry run mode)
/scripts/elevate-cpanel --check
```

### To upgrade

Once you have a backup of your server (**The cPanel elevate script does not back up before upgrading**), and have cleared upgrade blockers with Pre-upgrade checks, you can begin the migration.

**NOTE** This upgrade could take over 30 minutes. Be sure your users are aware that your server may be down and
unreachable during this time.


You can upgrade by running:
```bash
/scripts/elevate-cpanel --start
```

### Command line options

```bash
# Read the help (and risks mentionned in this documentation)
/scripts/elevate-cpanel --help

# Check if your server is ready for elevation (dry run mode)
/scripts/elevate-cpanel --check

# Start the migration
/scripts/elevate-cpanel --start

... # expect multiple reboots (~30 min)

# Check the current status
/scripts/elevate-cpanel --status

# Monitor the elevation log
/scripts/elevate-cpanel --log

# In case of errors, once fixed you can continue the migration process
/scripts/elevate-cpanel --continue
```

## Summary of upgrade process

The elevate process is divided in multiple `stages`.
Each `stage` is repsonsible for one part of the upgrade.
Between each stage a `reboot` is performed before doing a final reboot at the very end.

### Stage 1

Start the elevation process by installing the `elevate-cpanel` service responsible for the multiple reboots.

### Stage 2

Update the current distro packages.
Disable cPanel services and setup motd.

### Stage 3

Setup the elevate repo and install leapp packages.
Prepare the cPanel packages for the update.

Remove some known conflicting packages and backup some existing configurations. (these packages will be reinstalled druing the next stage).

Provide answers to a few leapp questions.

Attempt to perform the `leapp` upgrade.

In case of failure you probably want to reply to a few extra questions or remove some conflicting packages.

### Stage 4

At this stage we should now run an RHEL 8 based distro.
Update cPanel product for the new distro.

Restore removed packages during the previous stage.

### Stage 5

This is the final stage of the upgrade process.
Perform some sanity checks and cleanup.
Remove the `elevate-cpanel` service used during the upgrade process.

A final reboot is performed at the end of this stage.

## Advanced Options

### Using an alternative tool to upgrade your distro

By default, the elevate script runs the [leapp process](https://almalinux.org/elevate/)
to upgrade you from 7 to 8. `Leapp` may not be compatible with your system.

Using the `--upgrade-distro-manually` option gives you a way to do the actual distro upgrade in your own way.
This, for instance, can be used to allow `Virtuozzo` systems to upgrade cPanel systems, which are not supported by `Leapp`.

A `--upgrade-distro-manually` upgrade would look like:

1. User runs `/scripts/elevate-cpanel --start --upgrade-distro-manually` which starts the upgrade process.
2. `elevate-cpanel` does all preparatory steps to upgrade the system prior to the distro upgrade.
3. Elevate will then create the file `/waiting_for_distro_upgrade` to indicate that the operating system is ready for an upgrade.
    * This is when you would use your distro upgrade tool.
    * When you have completed upgrading your system to 8, simply remove `/waiting_for_distro_upgrade` and reboot the system into normal multi-user mode.
5. Elevate will resume upon reboot and complete the upgrade just like it would have without `--upgrade-distro-manually`

### Using the LEAPP_OVL_SIZE environment variable

By default, the elevate script will set this variable to 3000 before beginning the [leapp
process](https://almalinux.org/elevate/).  However, if you set this environment variable before
calling the elevate script, the elevate script will honor the environment variable and pass it
through to the [leapp process](https://almalinux.org/elevate/).

**NOTE** For more information on what this environment variable is used for, please review the
[leapp documentation for
it](https://leapp.readthedocs.io/en/latest/el7toel8/envars.html#leapp-ovl-size)

## FAQ

### How to check the current status?

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

### I need more help?

You can report an issue to [cPanel Technical Support](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/).

## Copyright

```c
Copyright 2024 WebPros International, LLC

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
