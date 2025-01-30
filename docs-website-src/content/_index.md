---
title: "cPanel ELevate Project"
date: 2022-12-07T08:53:47-05:00
draft: false
layout: single
---

# Welcome to the cPanel ELevate project!

The ELevate project aims to upgrade a cPanel installation with minimal outages. It builds and expands on the [Alma Linux ELevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project, which was created for in-place upgrades of RedHat-based systems.

[Pull requests are welcome](https://github.com/cpanel/elevate/pulls). Code contributions are subject to our [Contributor License Agreement](docs/cPanel-CLA.pdf)

## The cPanel ELevate project

This project will perform the following upgrades:

* CentOS 7 to AlmaLinux 8
* CloudLinux 7 to CloudLinux 8
* Ubuntu 20 to Ubuntu 22

The ELevate provides a wrapper around existing upgrade projects. While these projects are very effective at upgrading distribution packages, if you attempt to use them directly on a cPanel installation, you will end up with a broken system.

cPanel's ELevate wraps the following projects:
 * RHEL-based systems: the [LEAPP Project](https://leapp.readthedocs.io/en/latest/)
 * Ubuntu-based systems: the [do-release-upgrade](https://documentation.ubuntu.com/server/how-to/software/upgrade-your-release/) script.

For more information about the project, you can watch our [![cPanel ELevate walkthrough video](elevate-video.png)](https://www.youtube.com/watch?v=Ag9-RneFqmc).

### The project's approach

The cPanel ELevate project performs the following steps when it upgrades a distribution:

1. [Check for any blockers](https://cpanel.github.io/elevate/blockers/).
2. Update the system's distribution packages and reboot.
3. Analyze and uninstall any software that is commonly installed on cPanel systems. This does **not** include any of the system's data. This might include the following software:
  * cPanel (`upcp`)
  * EasyApache 4
  * MySQL or MariaDB
  * Distribution Perl/PECL binary re-installs
4. Perform the distribution upgrade.
5. Reinstall the software detected prior to upgrade.
6. Perform a final reboot to ensure that all services are running on the new binaries.

To start the process of ELevating your server, read our [ELevate Your Server](/getting-started.md) documentation.

## Need more help?

If you need more assistance, constact [cPanel Technical Support](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/).

## Disclaimer

We do **not** guarantee the functionality of software in this repository. You assume all risk for use of any software that you install from this repository. Installation of this software could cause significant functionality failures, even for experienced administrators.

That said, cPanel Technical Support is ready to help!
Please contact [cPanel Technical Support](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/) if you encounter problems.

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
