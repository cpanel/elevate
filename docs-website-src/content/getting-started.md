title: "ELevate Your Server"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

# ELevate Your cPanel Server

This document will provide the information you need to successfully ELevate your cPanel server to a new version.

You can perform the following elevations:

* CentOS 7 to AlmaLinux 8
* CloudLinux 7 to CloudLinux 8
* Ubuntu 20 to Ubuntu 22

## Requirements

Before you update your system, make **certain** that you've met the following requirements.

ELevate **requires** access to an interactive shell as the `root` user.

We **strongly** recommend that you have multiple ways to access your server before you attempt to upgrade. This ensures you're not locked out of the server if your primary method does not work. Ways to access your server may include the following methods:
  * `root` SSH access to the system.
  * Direct physical access to the console.
  * IPMI remote console access.
  * A virtual console through a hypervisor.
  * A custom system based on one of previous methods, made available by your server provider.

## Before you update your server

Before you ELevate your server, perform the following actions to ensure you're ready to start the process. Make certain that you review the [risks](#risks) for this process, as well.

We **strongly** recommend that you write down the information needed to [open a cPanel support request](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/#support-request-requirements). If you encounter issues during the upgrade process, this information may not be available from the system itself.

### Software verification

We recommend that you verify and update the software on your server before you start the ELevate process.

* Update your server's packages with your package manager. You can use one of the following commands:
  * RedHat-based servers: `yum update`
  * Ubuntu-based servers: `apt update`
* Ensure that you're using the latest stable version of cPanel & WHM. If you are not
* Make certain that you're using a version of MySQL/MariaDB that is compatible with the target distribution.

We also recommend that you [download the ELevate script](#download-the-elevate-cpanel-script) and [run the pre-checks](#pre-upgrade-checks). This will verify that you don't have any [blockers](/content/blockers.md) that will prevent you from upgrading.


### Backup the server

You **must** backup your server before you attempt to upgrade.

While the upgrade process attempts to account for conditions that might result in a broken system, this is not a guarantee. We **strongly** recommend that you backup your system with a whole-system image or snapshot.

If you must recover your system, you will need to reload the system from your image or snapshot.

The [cPanel Backup](https://docs.cpanel.net/whm/backup/) system **only** backs up individual cPanel accounts. Backups of individual cPanel accounts **only** protect data managed by cPanel. These backups **do not** contain any programs or data not managed by cPanel.  If a catastrophic failure happens during the upgrade process, you may have extensive downtime.

If you must recover your system from individual accounts, you will need to wipe the existing system, install the target operating system, install cPanel on the new operating system, rebuild all system customizations, and restore the cPanel accounts from the backup.

If individual cPanel account backups are your only backup option, and uptime is a critical consideration, we recommend that you use the [Transfer Tool](https://docs.cpanel.net/whm/transfers/transfer-tool/) to migrate to a new system instead of upgrading in-place using ELevate. This provides you with more control over the transition in the event of a failure.

If you do not know how much of your system your backup service covers, contact your backup service provider for more  information.

## Updating your server

### Download the elevate-cpanel script

Run the following command to download the ELevate script to your cPanel server:

```bash
wget -O /scripts/elevate-cpanel \
    https://raw.githubusercontent.com/cpanel/elevate/release/elevate-cpanel ;
chmod 700 /scripts/elevate-cpanel
```

### Run pre-upgrade checks

We recommend you check for [known blockers](/content/blockers.md) before you upgrade your server. The check will **not** make any changes to your system.

Run the collowing command to verify that your system is ready to upgrade:
```bash
# Check upgrade (dry run mode)
/scripts/elevate-cpanel --check
```

### Perform the upgrade

After you backup your server clear any upgrade blockers, you can begin your server's upgrade. The cPanel ELevate script does **not** perform a backup before upgrading

**NOTE** This upgrade may take over 30 minutes. Make certain that your users are aware that your server may be down and unreachable during this time.

Run the following command to start the upgrade process:
```bash
/scripts/elevate-cpanel --start
```

#### Script command line options

```bash
# Read the help (and risks mentioned in this documentation)
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

## Summary of the upgrade process

The ELevate process is divided in multiple `stages`.
Each `stage` is responsible for one part of the upgrade.
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
process](https://almalinux.org/elevate/).  However, if you set this environment variable before calling the elevate script, the elevate script will honor the environment variable and pass it through to the [leapp process](https://almalinux.org/elevate/).

**NOTE** For more information on what this environment variable is used for, please review the [leapp documentation for it](https://leapp.readthedocs.io/en/latest/el7toel8/envars.html#leapp-ovl-size)

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
