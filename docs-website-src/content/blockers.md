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

## Disk space

At any given time, the upgrade process may use at or more than 5 GB. If you have a complex mount system, we have determined that the following areas may require disk space for a period of time:

* **/boot**: 120 MB
* **/usr/local/cpanel**: 1.5 GB
* **/var/lib**: 5 GB

## Unsupported software

The following software is known to lead to a corrupt install if this script is used. We block elevation when it is detected:

* **cPanel CCS Calendar Server** - Requires Postgresql < 10.0
* **Postgresql** - ELevate upgrades you to Postgresql 10.x which makes it impossible to downgrade to a 9.x Postgresql.

## Things you need to upgrade first.

You can discover many of these issues by downloading `elevate-cpanel` and running `/scripts/elevate-cpanel --check`. Below is a summary of the major blockers people might encounter.

* **distro is up to date**
  * We expect yum update to indicate there is nothing to do.
  * Mitigation: `yum update`
* **cPanel is up to date**
  * You will need to be on a version mentioned in the "Latest cPanel & WHM Builds (All Architectures)" section at http://httpupdate.cpanel.net/
  * Mitigation: `/usr/local/cpanel/scripts/upcp`
* **nameserver**
  * cPanel provides support for a myriad of nameservers. (MyDNS, nsd, bind, powerdns). On AlmaLinux 8 / Rocky 8, it is preferred that you always be on PowerDNS.
  * Mitigation: `/scripts/setupnameserver powerdns`
* **MySQL**
  * 99% of existing AlmaLinux 8 / Rocky 8 cPanel installs end up with MySQL 8. We recommend you upgrade your MySQL to 8.0 if possible.
  * **MariaDB**: If you have already switched to MariaDB, you have no way of reaching MySQL. Be sure you are on 10.3 or better before moving to AlmaLinux 8 / Rocky 8.
* Some **EA4 packages** are not supported on AlmaLinux 8 / Rocky 8.
  * Example: PHP versions 5.4 through 7.1 are available on CentOS 7 but not AlmaLinux 8 / Rocky 8. You would need to remove these packages before the upgrading to AlmaLinux 8 / Rocky 8. Doing so might impact your system users. Proceed with caution.
