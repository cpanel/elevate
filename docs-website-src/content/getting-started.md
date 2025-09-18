---
title: "ELevate Your Server"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

# ELevate Your cPanel® Server

This document helps you to successfully ELevate your cPanel server to a new version.

You can perform the following elevations:

* CentOS 7 to AlmaLinux OS 8
* CloudLinux™ 7 to CloudLinux 8
* Ubuntu® 20 to Ubuntu 22
* AlmaLinux OS 8 to AlmaLinux OS 9
* CloudLinux™ 8 to CloudLinux 9

## Prerequisites

ELevate **requires** access to an interactive shell as the `root` user.

Before you upgrade your system, make **certain** that you've met the following requirements.

* You are logged in to the server as the `root` user.
* Your system runs CentOS 7, CloudLinux 7, Ubuntu 20, AlmaLinux OS 8, or CloudLinux 8.
  * Systems that run CentOS 7 or CloudLinux 7 **must** run cPanel & WHM version 110.
  * Systems that run Ubuntu 20 **must** run cPanel & WHM version 118.
  * Systems that run AlmaLinux OS 8 or CloudLinux 8 **must** run on a named tier (LTS, STABLE, RELEASE, CURRENT, or EDGE) of cPanel & WHM
* Your system **must** run the most recent minor version of its cPanel version for your operating system.
* cPanel **must** have a valid license.
* If applicable, **CloudLinux** has a valid license.

Additionally, the following **must** be true about the `elevate-cpanel` script:

* The script must run from the `/scripts` directory and use `/usr/local/cpanel/scripts` when called.
* The script must be up to date.

We **strongly** recommend that you have multiple ways to access your server before you attempt to upgrade. This ensures you're not locked out of the server if your primary access method does not work. Ways to access your server may include the following methods:
  * `root` SSH access to the system.
  * Direct physical access to the console.
  * IPMI remote console access.
  * A virtual console through a hypervisor.
  * A custom system based on one of previous methods, made available by your server provider.

## Before you upgrade your server

Before you ELevate your server, perform the following actions to ensure you're ready to start the process. Make certain that you review the [risks](#risks) for this process before you begin.

We **strongly** recommend that you write down the information needed to [open a cPanel support request](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/). If you encounter issues during the upgrade process, this information may not be available from the system itself.

### Software verification

We recommend that you verify and update the software on your server **before** you start the ELevate process.

* Update your server's packages with your package manager. You can use one of the following commands to update the packages:
  * Red Hat®-based servers: `yum update`
  * Ubuntu-based servers: `apt upgrade`
* Ensure that you're using the latest stable version of cPanel & WHM that is available for your current OS:
  * CentOS 7 and CloudLinux 7 support is only available on cPanel & WHM version 110.
  * Ubuntu 20.04 support is only available on cPanel & WHM version 118.
  * AlmaLinux 8 and CloudLinux 8 support is only available on name cPanel & WHM tiers such as RELEASE or LTS.
* Make certain that you're using a version of MySQL/MariaDB that is compatible with your target distribution.

We also recommend that you [download the ELevate script](#download-the-elevate-cpanel-script) and [run the pre-checks](#run-pre-upgrade-checks). This will ensure that you don't have any [blockers](https://cpanel.github.io/elevate/blockers/) that will prevent an upgrade.


### Backup the server

You **must** backup your server before you attempt to upgrade.

While the upgrade process attempts to account for conditions that might result in a broken system, this is not a guarantee. We **strongly** recommend that you backup your system with a whole-system image or snapshot.

If you must recover your system, you will need to reload the system from the image or snapshot you created.

The [cPanel Backup](https://docs.cpanel.net/whm/backup/) system **only** backs up individual cPanel accounts. Backups of individual cPanel accounts **only** protect data managed by cPanel. These backups **do not** contain any programs or data not managed by cPanel.  If a catastrophic failure happens during the upgrade process, you may have extensive downtime.

If you must recover your system from individual accounts, you will need to wipe the existing system, install the target operating system, install cPanel on the new operating system, rebuild all system customizations, and restore the cPanel accounts from the backup.

If individual cPanel account backups are your only backup option, and uptime is a critical consideration, we recommend that you use WHM's [Transfer Tool](https://docs.cpanel.net/whm/transfers/transfer-tool/) to migrate to a new system **instead** of upgrading in place using ELevate. This provides you with more control over the transition in the event of a failure.

If you do not know how much of your system your backup service covers, contact your backup service provider for more information.

## Upgrade your server

### Download the elevate-cpanel script

Run the following command to download the ELevate script to your cPanel server:

```bash
wget -O /scripts/elevate-cpanel \
    https://raw.githubusercontent.com/cpanel/elevate/release/elevate-cpanel ;
chmod 700 /scripts/elevate-cpanel
```

### Run pre-upgrade checks

We recommend that you check for [known blockers](https://cpanel.github.io/elevate/blockers/) before you upgrade your server. The check will **not** make any changes to your system.

Run the following command to verify that your system is ready to upgrade:
```bash
# Check upgrade (dry run mode)
/scripts/elevate-cpanel --check
```

### Perform the upgrade

After you backup your server and clear any upgrade blockers, you can begin your server's upgrade. The cPanel ELevate script does **not** perform a backup before upgrading.

**NOTE**: This upgrade may take over 30 minutes. Your server may be down and unreachable during this time.

Run the following command to start the upgrade process:

```bash
/scripts/elevate-cpanel --start
```

To read an overview of the ELevate process, read our [ELevate process](https://cpanel.github.io/elevate/#the-elevate-process) documentation.

#### Script command line options

The `/scripts/elevate-cpanel` script accepts the following options:

| Option | Description | Example |
| ----- | ----- | ----- |
| `--check` | Verify if your server is ready to run the script (dry run). | `/scripts/elevate-cpanel --check` |
| `--clean` | Clear the ELevate process' previous state. Do **not** use this option if the process is past Stage 2. | `/scripts/elevate-cpanel --clean` |
| `--continue` | Continue the ELevate process after fixing any errors. | `/scripts/elevate-cpanel --continue` |
| `--log` | Monitor the ELevate log. | `/scripts/elevate-cpanel --log` |
| `--status` | Display the status of the upgrade. | `/scripts/elevate-cpanel --status`
| `--start` | Start the ELevate process. | `/scripts/elevate-cpanel --start` |
| `--upgrade-distro-manually` | Perform the distribution upgrade manually. You can **only** use this option with the `--start` option. | `/scripts/elevate-cpanel --start --upgrade-distro-manually` |
| `--help` | Display the help text | `/scripts/elevate-cpanel --help` |


## Advanced Options

You can also implement the following advanced options when you ELevate your server.

### Use an alternative tool to upgrade your distribution

The cPanel ELevate script wraps the following projects, depending on your operating system:
 * RHEL-based systems: The [LEAPP Project](https://leapp.readthedocs.io/en/latest/)
 * Ubuntu-based systems: the [do-release-upgrade script](https://documentation.ubuntu.com/server/how-to/software/upgrade-your-release/)

You can use the `--upgrade-distro-manually` option to perform a distribution upgrade manually.

For example, you can use this option to allow Virtuozzo to upgrade cPanel systems, which is not supported by LEAPP.

To use the `--upgrade-distro-manually` option perform the following steps:

1. Run the `/scripts/elevate-cpanel --start --upgrade-distro-manually` command to start the upgrade process.

  The `elevate-cpanel` service will complete all the steps needed to upgrade the system until it reaches the distribution upgrade stage.

  ELevate will create the `/waiting_for_distro_upgrade` file, which indicates that the operating system is ready for an upgrade.

2. Use your distribution upgrade tool to complete the upgrade process.
3. When the upgrade is complete, delete the `/waiting_for_distro_upgrade` file and reboot the system into normal multi-user mode.

The ELevate script will resume after the reboot and complete the upgrade.

### Use the LEAPP_OVL_SIZE environment variable

This section **only** applies to servers that run CentOS 7 or AlmaLinux.

By default, the elevate script will set the `LEAPP_OVL_SIZE` variable to `3000` before it starts the ELevate process. However, if you set this environment variable before you call the ELevate script, the script will use the setting you provide.

For more information about the `LEAPP_OVL_SIZE` variable, read the [leapp documentation](https://leapp.readthedocs.io/en/latest/el7toel8/envars.html#leapp-ovl-size)

### Skip the logic that verifies that each sites PHP version remains the same after upgrade

Create the `/var/cpanel/elevate_skip_preserve_php_versions` touch file to indicate that you want to skip this logic and handle any potential breakage manually.

## Risks

When you upgrade your server, you may experience data loss or unexpected behavior that can render your server not functional.

Upgrades can take between 30 and 90 minutes to complete. For most of this time, the server will be degraded and non-functional. While the ELevate process attempts to disable the software so external systems will not fail, small windows still exist where unexpected failures may lead to some data loss.

Failure states may include but are not limited to the following states:

* Failure to upgrade the kernel due to custom drivers.
* Incomplete upgrade of software.

You may also experience the following issues, among others:
* Invalid cPanel binaries.
* Incorrect settings in cPanel.
* The cPanel CSS service may not start.
* Incorrect packages for EasyApache 4 and third-party software.
* Invalid manually installed PECL or Perl CPAN modules.
* MySQL may no longer be upgradable. For more information about supported versions of MySQL, read our [Supported MySQL/MariaDB versions](https://docs.cpanel.net/knowledge-base/general-systems-administration/supported-mysql-mariadb-versions/) documentation.

This list is not comprehensive. We **strongly** recommend you back up (and ideally create a snapshot of) your system before you attempt this process.

If you need more help, you can [open a ticket](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/).
