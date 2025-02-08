---
title: "Known cPanel ELevate Blockers"
date: 2022-03-23T16:13:47-05:00
draft: false
layout: single
---

# Overview

The ELevate script upgrades existing cPanel & WHM installations to a newer installation.

This document lists the blockers for successfully upgrading your system.

## Prerequisites

To successfully run the ELevate script, you must meet the following conditions:  

* You are logged in as the `root` user.
* The system runs CentOS 7, CloudLinux 7, or Ubuntu 20.
** For CentOS 7 and CloudLinux 7, you are running cPanel version 110.
** For Ubuntu 20, you are running cPanel version 118.
* You **must** be running the latest minor version of the respective cPanel version for your OS.
* cPanel has a valid license.
* If applicable, **CloudLinux** has a valid license.

Additionally, the following **must** be true about the `elevate-cpanel` script:

* The script runs from the `/scripts` directory and uses `/usr/local/cpanel/scripts` when called.
* The script must be up to date.

## Identify blockers

To identify many of your system's blockers, download the `elevate-cpanel` script and run the following command:

```
 /scripts/elevate-cpanel --check`
```

## Major blockers

The following installation or configuration states that will block your ELevate script from running. These blockers appear when the ELevate script **cannot** guarantee a successful upgrade.

### Disk space

The upgrade process may use 5 GB or more of disk space. If you use a complex mount system, the following areas may require more disk space.

* `/`: 5 GB
* `/boot`: 120 MB
* `/tmp`: 5 MB
* `/usr/local/cpanel`: 1.5 GB
* `/var/lib`: 5 GB

#### cPanel version

To run the ELevate script successfully, your server must run a supported version of cPanel & WHM. You can find the list of supported versions in our [Product Versions and the Release Process](https://docs.cpanel.net/knowledge-base/cpanel-product/product-versions-and-the-release-process/#releases) documentation.

Make certain that your system is running the most recently updated version. You can run the `/usr/local/cpanel/scripts/upcp` script to update the server.

#### The sshd config file

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
* AlmaLinux 8: PHP 7.2 and later
* CloudLinux 8: PHP 5.1 and later
* Ubuntu 22: PHP 8.1 and later

If any of your users use a PHP version earlier than these, the ELevate process will be **blocked**.
If these versions are only installed but not in use, the system will upgrade as normal, but these PHP versions will **not** be reinstalled.

#### Hardened PHP

If you use Imunify 360, it can provide hardened PHP for versions 5.1 and later. The upgrade process will detect these hardened PHP versions and allow the upgrade to occur.

### Filesystem mount command

The ELevate process reboots your system multiple times during the upgrade process. We ensure that the `mount -a` command succeeds before starting the ELevate process.  This helps to verify the filesystem will remain the same between each reboot.

### GRUB2 configuration

The system **must** be able to change the GRUB2 configuration so it can control the boot process.

The ELevate process **must** be able to run a custom early boot environment to upgrade the distribution. In order to make sure that we can run this environment, the process verifies that the system's current kernel version is the same as the system-identified default boot option. It also checks that a valid GRUB2 configuration exists.

#### Leapp preupgrade (dry run) check (RHEL based distros only)

If you start the ELevate process with the `--start` option, ELevate will perform an extra check before starting your upgrade **even if** no issues exist with your GRUB2 configuration. This extra check is a "dry run" of the distro upgrade performed by executing `leapp preupgrade`. This check will identify any problems that Leapp might encounter during the actual upgrade.

**NOTE**: If any errors are found, you **must** correct them before performing the upgrade.

### JetBackup version

If you run JetBackup, it **must** be version 5 or later. Earlier versions are **not** supported.

### Multiple network interface cards using kernel names

If your machine has multiple network interface cards (NICs) using kernel names (`ethX`), the process will offer to automatically update the name from `ethX` to `cpethX` during the upgrade process.

For more information about why this name change is necessary, read Freedesktop.org's [Predictable Network Interface Names](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/) documentation.

### MySQL version

A MySQL upgrade **can not** be in progress.

If the version of MySQL/MariaDB installed on the system is not supported on the target distribution, you **must** upgrade to a supported version. If cPanel manages your MySQL installation, the process will offer to upgrade MySQL automatically to MariaDB during elevation.

**NOTE:** In cases where an upgrade is necessary **and** the system is set up to use a remote server, a local server will be temporarily configured and enabled for the duration of the elevation, and the remote instance will be re-enabled once the elevation completes.

### OVH proactive intervention monitoring

If you use a dedicated server hosted at [OVH](https://www.ovhcloud.com/), you should **disable** the `proactive monitoring` **before** you start the ELevate process. Create the `/var/cpanel/acknowledge_ovh_monitoring_for_elevate` touch file to indicate that you disabled monitoring. This will prevent the proactive monitoring from incorrectly detecting an issue on your server during the reboots. If you do not create this file, your server may boot into rescue mode and interrupt the upgrade.

For more information about OVH monitoring, read their [Overview of OVHCloud Monitoring on Dedicated Servers](https://support.us.ovhcloud.com/hc/en-us/articles/115001821044-Overview-of-OVHcloud-Monitoring-on-Dedicated-Servers) documentation.

### APT lists (Ubuntu-based upgrades only)

The following issues with apt lists can cause ELevate to block your upgrade:
 * Apt is in an unstable state and running `apt-get clean` fails.
 * Apt has packages that are held back from upgrades as reported by `apt-mark showhold`. This can
   prevent `do-release-upgrade` from upgrading your distro.
 * Any unsupported list files are present in `/etc/apt/sources.list.d`.

### YUM repositories (RHEL-based upgrades only)

The following issues with yum repositories can cause ELevate to block your upgrade:
  * Invalid syntax or use of `\$`. That character is interpolated on RHEL 7-based systems, but not on systems that are RHEL 8-based.
  * Any unsupported repositories with packages installed.
  * If yum is in an unstable state and running `yum makecache` fails.

If any unfinished yum transactions are detected, ELevate will attempt to complete them by running the `/usr/sbin/yum-complete-transaction --cleanup-only` command. If this fails, ELevate will block the upgrade process until you manually resolve any outstanding issues or transactions.

#### Unsupported repositories

If you receive the following error message when you use this script, you have installed packages from an unsupported repository:

`One or more enabled YUM repo[sitories] are currently unsupported and have installed packages. You should disable these repositories and remove packages installed from them before continuing the update`.

We do not allow upgrades while you are using packages from unsupported repositories for the following reasons:

* We cannot guarantee that unsupported repositories provide packages for your upgraded distribution version.
* Even if an unsupported repository provides the packages for your upgraded distribution version, we cannot be certain that they will not interfere with your upgrade process.

To upgrade your distribution version, you **must** disable these repositories and remove their packages.

When the upgrade is complete, you can reenable and reinstall the repository, or install equivalent packages from other repositories. If no equivalent packages exist, you may need to find an alternative solution.
