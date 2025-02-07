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
* You are running cPanel version 110.
* cPanel does **not** require an update.
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

* `/boot`: 120 MB
* `/usr/local/cpanel`: 1.5 GB
* `/var/lib`: 5 GB

#### cPanel version

To run the ELevate script successfully, your server must run a supported versdion of cPanel & WHM. You can find the list of supported versions in our <a href="https://docs.cpanel.net/knowledge-base/cpanel-product/product-versions-and-the-release-process/#releases" target="_blank">Product Versions and the Release Process</a> documentation.

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
* AlmaLinux: PHP 7.2 and later on systems
* Ubuntu: PHP 7.3 and later

If any of your users use a PHP version earlier than these, the ELevate process will be **blocked**.
If these versions are only installed but not in use, the system will upgrade as normal, but these PHP versions will **not** be reinstalled.

#### Hardened PHP

If you use Imunify 360, it can provide hardened PHP for versions 5.1 through 7.1 on AlmaLinux as well as CentOS 7. The upgrade process will detect these hardened PHP versions and allow the upgrade to occur.

### Filesystem mount command

The ELevate process reboots your system multiple times during the upgrade process. We ensure that the `mount -a` commant succeeds starting the ELevate process.  The filesystem muat remain the same between each reboot.

### GRUB2 configuration

The system **must** be able to change the GRUB2 configuration so it can control the boot process.

The ELevate process **must** be able to run a custom early boot environment to upgrade the distribution. In order to make sure that we can run this environment, the process verifies that the system's current kernel version is the same as the system-identified default boot option. It also checks that a valid GRUB2 configuration exists.

#### Dry run check

If you start the ELevate process with the `--start` option, ELevate will perform an extra check before starting your upgrade **even if** no issues exist with your GRUB2 configuration. This extra check is a "dry run" upgrade. This check will identify any problems that it might encounter during the actual upgrade.

**NOTE**: If any errors are found, you **must** correct them before performing the upgrade.

### JetBackup version

If you run JetBackup, it **must** be version 5 or later. Earlier versions are **not** supported.

### Multiple network interface cards using kernel names

If your machine has multiple network interface cards (NICs) using kernel names (`ethX`), the process will offer to automatically update the name from `ethX` to `cpethX` during the upgrade process.

For more information about why this name change is necessary, read Freedesktop.org's <a href="https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/" target="_blank">Predictable Network Interface Names</a> documentation.

### MySQL version

A MySQL upgrade **can not** be in progress.

If the version of MySQL/MariaDB installed on the system is not supported on the target distribution, you **must** upgrade to a supported version. If cPanel manages your MySQL installation, the process will offer to upgrade MySQL automatically to MariaDB during elevation.

**NOTE:** In cases where an upgrade is necessary **and** the system is set up to use a remote server, a local server will be temporarily configured and enabled for the duration of the elevation, and the remote instance will be re-enabled once the elevation completes.

### OVH proactive intervention monitoring

If you use a dedicated server hosted at <a href="https://www.ovhcloud.com/" target="_blank">OVH</a>, you should **disable** the `proactive monitoring` **before** you start the ELevate process. Create the `/var/cpanel/acknowledge_ovh_monitoring_for_elevate` touch file to indicate that you disabld monitoring. This will prevent the proactive monitoring from incorrectly detecting an issue on your server during the reboots. If you do not create this file, your server may boot into rescue mode and interrupt the upgrade.

For more information about about OVH monitoring, read their <a href="https://support.us.ovhcloud.com/hc/en-us/articles/115001821044-Overview-of-OVHcloud-Monitoring-on-Dedicated-Servers" target="_blank">Overview of OVHCloud Monitoring on Dedicated Servers</a> documentation.

### PostgreSQL database directory

If you use the PostgreSQL software provided by your distribution (including PostgreSQL as installed by cPanel), ELevate will upgrade the software packages. However, your PostgreSQL service may not start properly. ELevate does **not** attempt to update the data directory being used by your PostgreSQL instance to store settings and databases. PostgreSQL detects this condition and may refuse to start until you perform an update.

If ELevate detects that one or more cPanel accounts have associated PostgreSQL databases, it will block you from beginning the upgrade process until you create the `/var/cpanel/acknowledge_postgresql_for_elevate` touch file.

#### Updating the PostgreSQL data directory after elevation

After ELevate completes the upgrade process, update your PostgreSQL data directory. Perform the following steps to update the PostgreSQL data directory:

**NOTE**:
* We **strongly recommend** that you make a backup copy of your data directory before starting. **cPanel cannot guarantee the correctness of these steps for any arbitrary PostgreSQL installation**.
* These steps assume that your server's data directory is located at `/var/lib/pgsql/data`.

1. Install the `postgresql-upgrade` package:
  * RHEL-based systems: `dnf install postgresql-upgrade`
  * Ubuntu-based systems: `apt install postgresql-upgrade`
2. Open the `/var/lib/pgsql/data/postgresql.conf` PostgreSQL config file  with your preferred text editor.
3. If the `unix_socket_directories` options exists and is active, change the option  `unix_socket_directory`. This will work around differencesd between your old operating system, PostgreSQL 9.2, and the PostgreSQL 9.2 helpers packaged the system's `postgresql-upgrade` package.
4. run the `postgresql-setup` tool with the following command:
```
/usr/bin/postgresql-setup --upgrade
```
4. Log into WHM as the `root` user, navigate to WHM's <a href="https://docs.cpanel.net/whm/database-services/configure-postgresql/" target="_blank">Configure PostgreSQL interface</a> (_WHM >> Home >> Database Services >> Configuration Postgre SQL_)  and click _Install Config_. This will restore the additions cPanel makes to the PostgreSQL access controls that allow phpPgAdmin to function.

### YUM repositories

The following ssues with yum repositories can cause ELevate to block your upgrade:
  * Invalid syntax or use of `\$`. That character is interpolated on RHEL 7-based systems, but not on systems that are RHEL 8-based.
  * Any unsupported repositories with packages installed.
  * If yum is in an unstable state and running `yum makecache` fails.

If any unfinished yum transactions are detected, ELevate will attempt to complete them by running the `/usr/sbin/yum-complete-transaction --cleanup-only` command. If this fails, ELevate will block the upgrade process until you manually resolve any outstanding issues or transactions.

#### Unsupported repositories

If you receive the following error message when you use this script, you have installed packages from an unsupported repository:

`One or more enabled YUM repo[sitories] are currently unsupported and have installed packages. You should disable these repositories and remove packages installed from them before continuing the update`.

We do not allow upgrades while you are using packages from unsupported repositories for the following reasons:

* We cannot guarantee that unsupported repositories provide packages for your upgraded distribution version.
* Even if an unsupported repository provides the packages for your upgraded distribution version, we cannot certain that they will not interfere with your upgrade process.

To upgrade your distribution version, you **must** disable these repositories and remove their packages.

When the upgrade is complete, you can reenable and reinstall the repository, or install equivalent packages from other repositories. If no equivalent packages exist, you may need to find an alternative solution.
