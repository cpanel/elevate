---
title: "cPanel ELevate CentOS 7 to AlmaLinux 8"
date: 2022-03-15T08:53:47-05:00
draft: false
layout: single
---

# Welcome to the cPanel ELevate Project.

## Goal

The cPanel ELevate Project provides a script to upgrade an existing `cPanel & WHM` CentOS 7 server installation to AlmaLinux 8.

## Introduction

- [Issues can be reported here](https://github.com/cpanel/elevate/issues)
- [Pull requests are welcome](https://github.com/cpanel/elevate/pulls)
    - Code contributions are subject to our [Contributor License Agreement](docs/cPanel-CLA.pdf)

This project builds on the [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project, which leans heavily on the [LEAPP Project](https://leapp.readthedocs.io/en/latest/) created for in-place upgrades of RedHat based systems.

The [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project is very effective at upgrading the distro packages from [CentOS&nbsp;7](https://www.centos.org/) to [AlmaLinux&nbsp;8](https://almalinux.org/). However if you attempt use it directly on a CentOS 7 based [cPanel install](https://www.cpanel.net/), you will end up with a broken system.

This project was designed to be a wrapper around the [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project to allow you to successfully upgrade a [cPanel install](https://www.cpanel.net/) with an aim to minimize outages.

### Our current approach can be summarized as:

1. [Check for blockers](docs/Known-blockers.md)
2. `yum update && reboot`
3. Analyze and remove software (not data) commonly installed on a cPanel system
4. [Execute AlmaLinux upgrade](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html)
5. Re-install previously removed software detected prior to upgrade. This might include:
  * cPanel (upcp)
  * EA4
  * MySQL variants
  * Distro Perl/PECL binary re-installs
6. Final reboot (assure all services are running on new binaries)

## Before updating

Before updating, please check that you met all the pre requirements:

* You will need to have console access available to your machine
* You should back up your server before attempting this upgrade
* Ensure your server is up to date: `yum update`
* Ensure you are using the last stable version of cPanel & WHM
* Use a version of MySQL/MariaDB compliant with Alamlinux 8.

Additional checks can be performed by [downloading the script](#download-the-elevate-cpanel-script)
and then [running pre-checks](#pre-upgrade-checks).

### Some of the problems you might find include:

* x86_64 RPMs not in the primary CentOS repos are upgraded.
  * `rpm -qa|grep el7`
* EA4 RPMs are incorrect
  * EA4 provides different dependencies and linkage on C7/A8
* cPanel binaries (cpanelsync) are invalid.
* 3rdparty repo packages are not upgraded (imunify 360, epel, ...).
* Manually installed Perl XS (arch) CPAN installs invalid.
* Manually installed PECL need re-build.
* Cpanel::CachedCommand is wrong.
* Cpanel::OS distro setting is wrong.
* MySQL might now not be upgradable (MySQL versions < 8.0 are not normally present on A8).
* The `nobody` user does not switch from UID 99 to UID 65534 even after upgrading to A8.

## Using the script

### Download the elevate-cpanel script

* You can download a copy of the script to run on your cPanel server via:

```bash
wget -O /scripts/elevate-cpanel \
    https://raw.githubusercontent.com/cpanel/elevate/release/elevate-cpanel ;
chmod 700 /scripts/elevate-cpanel
```

### Pre-upgrade checks

We recommend you check for known blockers before you upgrade. The check is designed to not make any changes to your system. You can do this by running:
```bash
# Check if your server is ready for elevation (dry run mode)
/scripts/elevate-cpanel --check
```

### To upgrade

Once you have a backup of your server (**The cPanel elevate script does not back up before upgrading**), and have cleared upgrade blockers with Pre-upgrade checks, you can begin the migration.

**NOTE** This upgrade could take over 30 minutes. Be sure your users are aware that your server may be down and
unreachable during this time.


```bash
# Start the migration
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

## Risks

As always, upgrades can lead to data loss or behavior changes that may leave you with a broken system.

Failure states include but are not limited to:

* Failure to upgrade the kernel due to custom drivers
* Incomplete upgrade of software because this code base is not aware of it.

We recommend you back up (and ideally snapshot) your system so it can be easily restored before continuing.

This upgrade will potentially take 30-90 minutes to upgrade all of the software. During most of this time, the server will be degraded and non-functional. We attempt to disable most of the software so that external systems will re-try later rather than fail in an unexpected way. However there are small windows where the unexpected failures leading to some data loss may occur.

**DISCLAIMER:** We do not guarantee the functionality of software in this repository, and we provide it on an experimental basis only. You assume all risk for any software that you install from this experimental repository. Installation of this software could cause significant functionality failures, even for experienced administrators.

## Copyright

```c
Copyright 2022 cPanel L.L.C.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, 
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, 
   this list of conditions and the following disclaimer in the documentation 
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, 
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE 
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```
