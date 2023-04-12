---
name: Failed upgrade
about: Failed Upgrade
title: "[UPG FAIL] "
labels: Needs Triage
assignees: ''

---

If you were able to upgrade but something has gone wrong, the quickest way to get help is to open a ticket with [cPanel Technical Support](https://docs.cpanel.net/knowledge-base/technical-support-services/how-to-open-a-technical-support-ticket/). 

NOTE:
 * During stage 3, a reboot will happen and the server will be inaccessible from the network for an extended period of time while distro packages are upgraded. [We recommend you have console access](https://cpanel.github.io/elevate/#before-updating) prior to start so you can know if it is hung or simply running slow.
 * If an error occurs during the elevation process, once you have fixed it, you can resume
the update process by running: `/scripts/elevate-cpanel --continue`

If you would still like to report your issue here, please include as much information as possible about the failure.
