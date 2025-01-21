title: "ELevate Your Server"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

## Prerequisites

Before you update your system, make certain that you've met the following requirements:

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

Additional checks can be performed by [downloading the script](#download-the-elevate-cpanel-script) and then [running pre-checks](#pre-upgrade-checks).

## Risks

As always, upgrades can lead to data loss or behavior changes that may leave you with a broken system.

Failure states include but are not limited to:

* Failure to upgrade the kernel due to custom drivers
* Incomplete upgrade of software because this code base is not aware of it.

We recommend you back up (and ideally snapshot) your system so it can be easily restored before continuing.

This upgrade will potentially take 30-90 minutes to upgrade all of the software. During most of this time, the server will be degraded and non-functional. We attempt to disable most of the software so that external systems will re-try later rather than fail in an unexpected way. However there are small windows where the unexpected failures leading to some data loss may occur.


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
