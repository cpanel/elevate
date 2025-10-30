---
title: "Known cPanel ELevate Blockers"
date: 2022-03-23T16:13:47-05:00
draft: false
layout: single
---

# cPanel ELevate blockers

The ELevate script upgrades existing cPanel & WHM® installations to a newer installation.

This document lists the blockers for successfully upgrading your system.

## Prerequisites

To successfully run the ELevate script, you must meet the following conditions:  

* You are logged in to the server as the `root` user.
* Your system runs CentOS 7, CloudLinux 7, Ubuntu 20, Ubuntu 22, AlmaLinux OS 8, CloudLinux 8, or AlmaLinux OS 9.
  * Systems that run CentOS 7 or CloudLinux 7 **must** run cPanel & WHM version 110.
  * Systems that run Ubuntu 20 **must** run cPanel & WHM version 118.
  * Systems that run Ubuntu 22 **must** run cPanel & WHM version 132.
  * Systems that run AlmaLinux OS 8, CloudLinux 8, or AlmaLinux OS 9 **must** run on a named tier (LTS, STABLE, RELEASE, CURRENT, or EDGE) of cPanel & WHM
* Your system **must** run the most recent [minor version](https://docs.cpanel.net/knowledge-base/cpanel-product/product-versions-and-the-release-process/#version-numbers) of its cPanel version for your operating system.
* cPanel **must** have a valid license.
* If applicable, **CloudLinux** has a valid license.

Additionally, the following **must** be true about the `elevate-cpanel` script:

* The script must run from the `/scripts` directory and use `/usr/local/cpanel/scripts` when called.
* The script must be up to date.

We **strongly** recommend that you have multiple ways to access your server before you attempt to upgrade. This ensures you're not locked out of the server if your primary access method does not work. You could access your server by many methods, including the following methods:
  * `root` SSH access to the system.
  * Direct physical access to the console.
  * IPMI remote console access.
  * A virtual console through a hypervisor.
  * A custom system based on one of previous methods, made available by your hosting provider.

## Identify blockers

To identify many blockers, [download the `elevate-cpanel`](https://cpanel.github.io/elevate/getting-started/#updating-your-server) script and run the following command:

```
 /scripts/elevate-cpanel --check
```

## Major blockers

The following installation or configuration states will **block** the cPanel ELevate script. The ELevate script **cannot** guarantee a successful upgrade if these blockers are present.

### Disk space

The upgrade process may use 5 GB or more of disk space. If you use a complex mount system, the following areas may require more disk space.

* `/`: 5 GB
* `/boot`: 120 MB
* `/tmp`:
  * 5 MB for RHEL-based systems
  * 750 MB for Ubuntu-based systems
* `/usr/local/cpanel`: 1.5 GB
* `/var/lib`: 5 GB

### The sshd config file

The script will **not** run successfully if the `sshd` config file is absent or unreadable.

### Conflicting processes

The following processes **will block** the ELevate script if they run at the same time:

* `/usr/local/cpanel/scripts/upcp`
* `/usr/local/cpanel/bin/backup`

**NOTE**: These checks are only enforced when you execute the script in `start` mode.

### Container-like environment

You can **not** run the ELevate process if your system runs in a container-like environment.

### EasyApache 4 packages

You **must** remove **EA4 packages** that are not supported by your targeted operating system before upgrading. As this might impact your cPanel users, proceed with caution.

#### PHP versions

We only support the following PHP versions:
* AlmaLinux OS 8: PHP 7.2 and later
* CloudLinux 8: PHP 5.1 and later
* Ubuntu 22: PHP 8.1 and later
* Ubuntu 24: PHP 8.1 and later
* AlmaLinux OS 9: PHP 8.0 and later
* CloudLinux 9: PHP 5.6 or later
* AlmaLinux 10: PHP 8.1 and later

If any of your users use a PHP version earlier than these, the ELevate process will be **blocked**.
If these PHP versions are only installed but not in use, the system will upgrade as normal, but the PHP versions will **not** be reinstalled.

#### Hardened PHP

[Imunify 360](https://www.imunify360.com/) provides hardened PHP for earlier versions of PHP. The upgrade process will detect these hardened PHP versions and allow the upgrade to occur.

### Filesystem mount command

The ELevate process reboots your system multiple times during the upgrade process. We ensure that the `mount -a` command succeeds before starting the ELevate process.  This helps to verify the filesystem will remain the same between each reboot.

### GRUB2 configuration

The system **must** be able to change the GRUB2 configuration so it can control the boot process.

The ELevate process **must** be able to run a custom early boot environment to upgrade the distribution. In order to make sure that we can run this environment, the process verifies that the system's current kernel version is the same as the system-identified default boot option. It also checks that a valid GRUB2 configuration exists.

#### Leapp preupgrade check

This **only** applies to RHEL-based systems.

If you start the ELevate process with the `--start` option, ELevate will perform an extra check before it starts your upgrade **even if** no issues exist with your GRUB2 configuration. This extra check runs the `leapp preupgrade` command and is a "dry run" of the distribution upgrade. This dry run identifies any problems that Leapp might encounter during the actual upgrade, but does not make any changes to the system.

**NOTE**: If this check identifies any errors, you **must** correct them before performing the upgrade.

### JetBackup version

If you run JetBackup, it **must** be version 5 or later. Earlier versions are **not** supported.

### Multiple network interface cards using kernel names

If your machine has multiple network interface cards (NICs) using kernel names (`ethX`), the process will offer to automatically update the name from `ethX` to `cpethX` during the upgrade process.

For more information about why this name change is necessary, read Freedesktop.org's [Predictable Network Interface Names](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/) documentation.

### MySQL version

A MySQL upgrade **can not** be in progress.

If the version of MySQL/MariaDB installed on the system is not supported on the target distribution, you **must** upgrade to a supported version. If cPanel manages your MySQL installation, the process will offer to upgrade MySQL automatically to MariaDB during elevation.

**NOTE:** If an upgrade is necessary **and** the system is set up to use a remote server, a local server will be temporarily configured and enabled for the duration of the ELevate process. The remote instance will be reenabled once the upgrade completes.

### cPanel securetmp

**NOTE:** Ubuntu-based systems only

If ELevate detects that cPanel securetmp is installed, it will disable cPanel securetmp before attempting to perform the distro upgrade.  The reason for this is that the `do-release-upgrade` script that is used to upgrade the distro can potentially use a larger amount of disk space than what cPanel allocates to `/tmp` when enabling securetmp.  Once the distro has successfully been updated, ELevate will re-enable cPanel securetmp.

### OVH proactive intervention monitoring

If you use a dedicated server hosted at [OVH](https://www.ovhcloud.com/), you should **disable** the proactive monitoring **before** you start the ELevate process. Create the `/var/cpanel/acknowledge_ovh_monitoring_for_elevate` touch file to indicate that you disabled monitoring. This will prevent the proactive monitoring from incorrectly detecting an issue on your server during the reboots. If you do **not** create this file, your server may boot into rescue mode and interrupt the upgrade.

For more information about OVH monitoring, read their [Overview of OVHCloud Monitoring on Dedicated Servers](https://support.us.ovhcloud.com/hc/en-us/articles/115001821044-Overview-of-OVHcloud-Monitoring-on-Dedicated-Servers) documentation.

### APT lists

This section **only** applies to Ubuntu-based systems.

The following issues with apt lists can cause ELevate to block your upgrade:
 * Apt is in an unstable state and running `apt-get clean` fails.
 * Apt has packages that are held back from upgrades as reported by `apt-mark showhold`. This can prevent `do-release-upgrade` from upgrading your system.
 * Any unsupported list files are in the `/etc/apt/sources.list.d` directory.

### YUM repositories

This section **only** applies to RHEL-based systems.

The following issues with yum repositories can cause ELevate to block your upgrade:
  * Invalid syntax or use of `\$`. That character is interpolated on RHEL 7-based systems, but not on systems that are RHEL 8-based.
  * Any unsupported repositories with packages installed.
  * If yum is in an unstable state and running `yum makecache` fails.

If any unfinished yum transactions are detected, ELevate will attempt to complete them by running the `/usr/sbin/yum-complete-transaction --cleanup-only` command. If this fails, ELevate will block the upgrade process until you manually resolve any outstanding issues or transactions.

#### Unsupported repositories

If you receive the following error message when you use this script, you have installed packages from an unsupported repository:

`One or more enabled YUM repo[sitories] are currently unsupported and have installed packages. You should disable these repositories and remove packages installed from them before continuing the update`.

We do not allow upgrades while you are using packages from unsupported repositories for the following reasons:

* We cannot guarantee that the packages in these unsupported repositories are supported by your upgraded distribution version.
* Even if an unsupported repository provides the packages for your upgraded distribution version, we cannot be certain that they will not interfere with your upgrade process.

To upgrade your distribution version, you **must** disable these repositories and **remove** their packages.

When the upgrade is complete, you can reenable and reinstall the repository, or install equivalent packages from other repositories. If no equivalent packages exist, you may need to find an alternative solution.
