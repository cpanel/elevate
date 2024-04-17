---
title: "Known cPanel ELevate Blockers"
date: 2022-03-23T16:13:47-05:00
draft: false
layout: single
---

# Known Blockers

The following is a list of install states which the script will intentionally prevent you from upgrading with. This is because the script cannot garantuee a successful upgrade with these conditions in place.

## Basic checks

The following conditions are assumed to be in place any time you run this script:

* You have **CentOS 7.9** or greater installed.
  * We DO NOT support alternative RHEL 7 (including CloudLinux) variants.
* You have cPanel version 102 or greater installed.
* You are logged in as **root**.

## Conflicting Processes

The following processes are known to conflict with this script and cannot be executed simulaneously.

* `/usr/local/cpanel/scripts/upcp`
* `/usr/local/cpanel/bin/backup`

**NOTE** These checks are only enforced when the script is executed in start mode

## Disk space

At any given time, the upgrade process may use at or more than 5 GB. If you have a complex mount system, we have determined that the following areas may require disk space for a period of time:

* **/boot**: 120 MB
* **/usr/local/cpanel**: 1.5 GB
* **/var/lib**: 5 GB

## Unsupported software

The following software is known to lead to a corrupt install if this script is used. We block elevation when it is detected:

* **cPanel CCS Calendar Server** - Requires Postgresql older than 10.0

## Things you need to upgrade first.

You can discover many of these issues by downloading `elevate-cpanel` and running `/scripts/elevate-cpanel --check`. Below is a summary of the major blockers people might encounter.

* **distro is up to date**
  * We expect yum update to indicate there is nothing to do.
  * Mitigation: `yum update`
* **cPanel is up to date**
  * You will need to be on a version mentioned in the "Latest cPanel & WHM Builds (All Architectures)" section at http://httpupdate.cpanel.net/
  * Mitigation: `/usr/local/cpanel/scripts/upcp`
* **nameserver**
  * cPanel provides support for a myriad of nameservers. (MyDNS, nsd, bind, powerdns). On AlmaLinux 8, it is preferred that you always be on PowerDNS.
  * Mitigation: `/scripts/setupnameserver powerdns`
* **MySQL**
  * We will upgrade you automatically to MariaDB 10.6 during elevation if you do not do this in advance.
* Some **EA4 packages** are not supported on AlmaLinux 8.
  * Example: PHP versions 5.4 through 7.1 are available on CentOS 7 but not AlmaLinux 8. You would need to remove these packages before the upgrading to AlmaLinux 8. Doing so might impact your system users. Proceed with caution.
* The system **must** be able to control the boot process by changing the GRUB2 configuration.
  * The reason for this is that the framework which performs the upgrade of distro-provided software needs to be able to run a custom early boot environment (initrd) in order to safely upgrade the distro.
  * We check for this by seeing whether the kernel the system is currently running is the same version as that which the system believes is the default boot option.
* Your machine has multiple network interface cards (NICs) using kernel-names (`ethX`).
  * Since `ethX` style names are automatically assigned by the kernel, there is no guarantee that this name will remain the same upon upgrade to a new kernel version tier.
  * The "default" approach in `network-scripts` config files of specificying NICs by `DEVICE` can cause issues due to the above.
  * A more in-depth explanation of *why* this is a problem (and what to do about it) can be found at [freedesktop.org](https://www.freedesktop.org/wiki/Software/systemd/PredictableNetworkInterfaceNames/).
  * One way to prevent these isssues is to assign a name you want in the configuration and re-initialize NICs ahead of time.

# Other Known Issues

The following is a list of other known issues that could prevent your server's successful elevation.

## PostgreSQL

If you are using the PostgreSQL software provided by your distro (which includes PostgreSQL as installed by cPanel), ELevate will upgrade the software packages. However, your PostgreSQL service is unlikely to start properly. The reason for this is that ELevate will **not** attempt to update the data directory being used by your PostgreSQL instance to store settings and databases; and PostgreSQL will detect this condition and refuse to start, to protect your data from corruption, until you have performed this update.

To ensure that you are aware of this requirement, if it detects that one or more cPanel accounts have associated PostgreSQL databases, ELevate will block you from beginning the upgrade process until you have created a file at `/var/cpanel/acknowledge_postgresql_for_elevate`.

### Updating the PostgreSQL data directory

Once ELevate has completed, you should then perform the update to the PostgreSQL data directory. Although we defer to the information [in the PostgreSQL documentation itself](https://www.postgresql.org/docs/10/pgupgrade.html), and although [Red Hat has provided steps in their documentation](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/deploying_different_types_of_servers/using-databases#migrating-to-a-rhel-8-version-of-postgresql_using-postgresql) which should be mostly applicable to all distros derived from RHEL 8, we found that the following steps worked in our testing to update the PostgreSQL data directory. (Please note that these steps assume that your server's data directory is located at `/var/lib/pgsql/data`; your server may be different. You should also consider making a backup copy of your data directory before starting, because **cPanel cannot guarantee the correctness of these steps for any arbitrary PostgreSQL installation**.)

1. Install the `postgresql-upgrade` package: `dnf install postgresql-upgrade`
2. Within your PostgreSQL config file at `/var/lib/pgsql/data/postgresql.conf`, if there exists an active option `unix_socket_directories`, change that phrase to read `unix_socket_directory`. This is necessary to work around a difference between the CentOS 7 PostgreSQL 9.2 and the PostgreSQL 9.2 helpers packaged by your new operating system's `postgresql-upgrade` package.
3. Invoke the `postgresql-setup` tool: `/usr/bin/postgresql-setup --upgrade`.
4. In the root user's WHM, navigate to the "Configure PostgreSQL" area and click on "Install Config". This should restore the additions cPanel makes to the PostgreSQL access controls in order to allow phpPgAdmin to function.

## Using OVH proactive intervention monitoring

If you are using a dedicated server hosted at OVH, you should **disable the `proactive monitoring` before starting** the elevation process.
The proactive monitoring incorrectly detects an issue on your server during one of the reboots.
Your server would then boot to a rescue mode, interrupting the elevation upgrade.

[Read more about OVH monitoring](https://support.us.ovhcloud.com/hc/en-us/articles/115001821044-Overview-of-OVHcloud-Monitoring-on-Dedicated-Servers)
