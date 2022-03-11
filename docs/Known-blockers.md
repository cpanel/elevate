# Known Blockers

The following is a list of install states which the script will intentionally prevent you from upgrading with. This is because the script cannot garantuee a successful upgrade with these conditions in place.

## Basic checks

The following conditions are assumed to be in place any time you run this script:

* You have **CentOS 7.9** or greater installed.
  * We DO NOT support alternative RHEL 7 (including CloudLinux) variants.
* You are logged in as **root**.

## Disk space

At any given time, the upgrade process may use at or more than 3 GB. If you have a complex mount system, we have determined that the following areas may require disk space for a period of time:

* **/boot**: 120 MB
* **/usr/local/cpanel**: 1.5 GB
* **/var/lib**: 3 GB

## Unsupported software

The following software is known to lead to a corrupt install if this script is used. We block elevation when it is detected:

* cPanel CCS Calendar Server - Requires Postgresql < 10.0
* Postgresql - Elevate upgrades you to Postgresql 10.x which makes it impossible to downgrade to a 9.x Postgresql.

## Things you need to upgrade first

* **nameserver**: cPanel provides support for a myriad of nameservers. (MyDNS, nsd, bind, powerdns). On AlmaLinux 8, it is preferred that you always be on PowerDNS.
  * Mitigation: `/scripts/setupnameserver powerdns`
* **MySQL**: 99% of existing AlmaLinux 8 cPanel installs end up with MySQL 8. We recommend you upgrade your MySQL to 8.0 if possible.
  * **MariaDB**: If you have already switched to MariaDB, you have no way of reaching MySQL. Be sure you are on 10.3 or better before moving to AlmaLinux 8.

## Network configuration

If you have multiple kernel-named Network Interface Cards (NICs) such as "eth0", "eth1", etc. which are not virtual devices, you need to rename them before running elevate.

The following code will tell you if you're affected:

```bash
[ $(ip link | egrep '^[0-9]+: eth[0-9]+:' | wc -l) -ge 1 ] && [ $(readlink /sys/class/net/* | grep -v '/virtual/' | wc -l) -ge 2 ] && echo 'Upgrade your NIC configuration'
```

