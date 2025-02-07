---
title: "cPanel ELevate Project"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

# Welcome to the cPanel ELevate project

The ELevate project aims to upgrade a cPanel installation with minimal outages. It builds and expands on the [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project, which was created for in-place upgrades of RedHat-based systems.

[Pull requests are welcome](https://github.com/cpanel/elevate/pulls). Code contributions are subject to our [Contributor License Agreement](docs/cPanel-CLA.pdf)

## The cPanel ELevate project

This project will perform the following upgrades:

* CentOS 7 to AlmaLinux 8
* CloudLinux 7 to CloudLinux 8
* Ubuntu 20 to Ubuntu 22

The ELevate provides a wrapper around existing upgrade projects. While these projects are very effective at upgrading distribution packages, if you attempt to use them directly on a cPanel installation, you will end up with a broken system.

cPanel's ELevate wraps the following projects:
 * RHEL-based systems: The <a href="https://leapp.readthedocs.io/en/latest/" target="_blank">LEAPP Project</a>.
 * Ubuntu-based systems: The <a href="https://documentation.ubuntu.com/server/how-to/software/upgrade-your-release/" target="_blank">do-release-upgrade</a> script.

For more information about the project, you can watch our [![cPanel ELevate walkthrough video](elevate-video.png)](https://www.youtube.com/watch?v=Ag9-RneFqmc).

### The ELevate process

The cPanel ELevate project [checks for any blockers](https://cpanel.github.io/elevate/blockers/) before it starts the upgrade process. The process is performed in stages. The server reboots between each stage and then does a final reboot when the process is complete.

#### Stage 1

Install the `elevate-cpanel` service.

#### Stage 2

Update the system's distribution packages, disable any cPanel services, and set the message-of-the-day (motd) to inform users an upgrade is in process.

#### Stage 3

Configure the ELevate repository.

Update cPanel packages, remove any conflicting packages, then back up the existing configuration.
NOTE: The backup **not** include any of the system's data. However, it might include the configuration for the following software:
  * cPanel (`upcp`)
  * EasyApache 4
  * MySQL or MariaDB
  * Distribution Perl/PECL binary re-installs

The system may ask you to provide answers to some questions before it can start the upgrade process.

#### Stage 4

Upgrade the server to the new distribution and restore the removed packages.  

#### Stage 5

Verify the installation and clean up the server. This includes removing the `elevate-cpanel` service.

To start the ELevate process and upgrade your server, read our [ELevate Your Server](/content/getting-started/) documentation.

## Need more help?

If you need more assistance, constact <a href="https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/" target="_blank">cPanel Technical Support</a>.

## Disclaimer

We do **not** guarantee the functionality of software in this repository. You assume all risk for use of any software that you install from this repository. Installation of this software could cause significant functionality failures, even for experienced administrators.


## Copyright

```c
Copyright 2024 WebPros International, LLC

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
