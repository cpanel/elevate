---
title: "Known cPanel ELevate Blockers"
date: 2022-03-23T16:13:47-05:00
draft: false
layout: single
---

# Overview

The ELevate script upgrades an existing cPanel & WHM RHEL 7-based server installation to a RHEL 8-based installation. This document covers the script's basic checks and blockers.

## Basic assumptions

We assume the following conditions any time you run the ELevate script:

* You are logged in as `root`.
* The system is running **CentOS** or **CloudLinux** 7.9.
* You are running cPanel version 110.
* cPanel does not require an update.
* cPanel has a valid license.
* If applicable, **CloudLinux** has a valid license.

Additionally, the following conditions **must** be true about the `elevate-cpanel` script:

* The script must be running from: `/scripts` or `/usr/local/cpanel/scripts`.
* The script must be up to date.

## Discovering blockers

You can discover many of your system's blockers by downloading `elevate-cpanel` and running `/scripts/elevate-cpanel --check`.

## Major blockers

The following is a list of installation or configuration states that will block your ELevate script from running. These blockers appear when the ELevate script **cannot** guarantee a successful upgrade.

### Disk space

At any given time, the upgrade process may use 5 GB or more. If you have a complex mount system, we have determined that the following areas may require more disk space for a period of time:

* **/boot**: 120 MB
* **/usr/local/cpanel**: 1.5 GB
* **/var/lib**: 5 GB
#### cPanel version


### Conflicting processes

The following processes **will block** the ELevate script if they are running the same time:

* `/usr/local/cpanel/scripts/upcp`
* `/usr/local/cpanel/bin/backup`

**NOTE**: These checks are only enforced when you execute the script in `start` mode.

#### Container-like environment

We do **not** support running the system in a container-like environment.

### cPanel version

**cPanel & WHM must be up to date.**

To run the ELevate script successfully, you will need to be on a version mentioned in the _Latest cPanel & WHM Builds (All Architectures)_ section at http://httpupdate.cpanel.net/.

If you are not on a version mentioned in <a href="http://httpupdate.cpanel.net/" "target=_blank">_Latest cPanel & WHM Builds (All Architectures)_</a> section, run the `/usr/local/cpanel/scripts/upcp` script to update.

### EA4 packages

You **must** remove **EA4 packages** that are not supported on AlmaLinux 8 before upgrading. Since this might impact your cPanel users, proceed with caution.

#### PHP versions

PHP versions 5.4 through 7.1 are available from cPanel on CentOS 7, but not AlmaLinux 8.
    * If these PHP versions are in use by any cPanel users, we **block** the elevation from proceeding.
    * If you have installed these PHP versions, but no one is using them, we allow the elevation to proceed. However, these PHP versions will **not*** be installed after the elevation completes.

#### Hardened PHP

If you have installed Imunify 360, it can provide hardened PHP for versions 5.1 through 7.1 on AlmaLinux 8 as well as CentOS 7. We now detect these hardened PHP versions and allow an elevation with them to proceed.

### Filesystem mount command

Since Elevate needs to reboot your system multiple times as part of the upgrade process, we ensure that the command `mount -a` succeeds before allowing the elevation to proceed.  This is because we need to be able to trust that the filesystem remains the same between each reboot.

### GRUB2 configuration

The system **must** be able to control the boot process by changing the GRUB2 configuration.
  * The reason for this is that the Leapp framework, which performs the upgrade of distribution-provided software, needs to be able to run a custom early boot environment (`initrd`) in order to safely upgrade the distribution.
  * We check that the Leapp framework can run a custom early boot environment by checking whether the system's current kernel version is the same as the system-identified default boot option.
  * We also check that there is a valid GRUB2 config.

#### Leapp preupgrade (dry run) check

If you invoke the ELevate script with the `--start` option, ELevate will perform an extra check before starting your upgrade **even if** there are no issues with your GRUB2 configuration. This extra check is a "dry run" of the Leapp upgrade performed by executing `leapp preupgrade`. This check will point out any problems that Leapp would encounter during the actual upgrade.

**NOTE**: If any errors are found, you **must** address them before performing the upgrade.

### JetBackup version

If you are running JetBackup, it **must** be version 5 or greater. Earlier versions are not supported.

### Multiple network interface cards using kernel names

We block if your machine has multiple network interface cards (NICs) using kernel names (`ethX`).
  * Since `ethX` style names are automatically assigned by the kernel, there is no guarantee that this name will remain the same upon upgrade to a new kernel version tier.
  * The "default" approach in `network-scripts` config files of specifying NICs by `DEVICE` can cause issues due to the above.
  * To find a more in-depth explanation of *why* this is a problem (and what to do about it), read Freedesktop.org's <a href="https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/" target="_blank">Predictable Network Interface Names</a> documentation.

One way to prevent these issues is to assign a custom name in the configuration and re-initialize NICs ahead of time.

### MySQL version

A MySQL upgrade **cannot be** in progress.

If the version of MySQL/MariaDB installed on the system is not supported on RHEL 8-based distributions, you **must** upgrade to a supported version. If cPanel manages the MySQL installation, we will offer to upgrade MySQL automatically to MariaDB 10.6 during elevation.

The system **must** not be set up to use a remote database server.

## OVH proactive intervention monitoring

If you are using a dedicated server hosted at OVH, you should **disable the `proactive monitoring` before starting** the elevation process. To indicate you have done this, you must create the touch file `/var/cpanel/acknowledge_ovh_monitoring_for_elevate`. This prevents the proactive monitoring from incorrectly detecting an issue on your server during one of the reboots and booting into rescue mode, which would interrupt the elevation upgrade.

To learn more about OVH monitoring, read their <a href="https://support.us.ovhcloud.com/hc/en-us/articles/115001821044-Overview-of-OVHcloud-Monitoring-on-Dedicated-Servers" target="_blank">Overview of OVHCloud Monitoring on Dedicated Servers</a> documentation.

### PostgreSQL database directory

If you are using the PostgreSQL software provided by your distribution (which includes PostgreSQL as installed by cPanel), ELevate will upgrade the software packages. However, your PostgreSQL service is unlikely to start properly. The reason for this is that ELevate will **not** attempt to update the data directory being used by your PostgreSQL instance to store settings and databases. Often, PostgreSQL detects this condition and refuses to start until you have performed the update.

To ensure that you are aware of this requirement, if it detects that one or more cPanel accounts have associated PostgreSQL databases, ELevate will block you from beginning the upgrade process until you have created a file at `/var/cpanel/acknowledge_postgresql_for_elevate`.

#### Updating the PostgreSQL data directory after elevation

Once ELevate has completed, you should perform the update to the PostgreSQL data directory. Although we defer to the information in <a href="https://www.postgresql.org/docs/10/pgupgrade.html" target="_blank">the PostgreSQL documentation</a>, and although <a href="https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/using-databases#migrating-to-a-rhel-8-version-of-postgresql_using-postgresql" target="_blank">Red Hat has provided steps in their documentation</a>, we found that the following steps worked in our testing to update the PostgreSQL data directory:

**NOTE**:
* We **strongly recommend** that you make a backup copy of your data directory before starting, because **cPanel cannot guarantee the correctness of these steps for any arbitrary PostgreSQL installation**.
* These steps assume that your server's data directory is located at `/var/lib/pgsql/data`.

1. Install the `postgresql-upgrade` package: `dnf install postgresql-upgrade`
2. Within your PostgreSQL config file at `/var/lib/pgsql/data/postgresql.conf`, if there exists an active option `unix_socket_directories`, change that phrase to read `unix_socket_directory`. This is necessary to work around a difference between the CentOS 7, PostgreSQL 9.2, and the PostgreSQL 9.2 helpers packaged by your new operating system's `postgresql-upgrade` package.
3. Invoke the `postgresql-setup` tool: `/usr/bin/postgresql-setup --upgrade`.
4. In the root user's WHM, navigate to the "Configure PostgreSQL" area and click on "Install Config". This should restore the additions cPanel makes to the PostgreSQL access controls in order to allow phpPgAdmin to function.

#### The sshd config file

The script will not run successfully if the `sshd` config file is absent or unreadable.

#### YUM repositories

These issues with the YUM repositories can cause ELevate to block your upgrade:
  * Invalid syntax or use of `\$`. That character is interpolated on RHEL 7-based systems, but not on systems that are RHEL 8-based.
  * Any unsupported repositories that have packages installed.
  * If YUM is in an unstable state (running `yum makecache` fails).
