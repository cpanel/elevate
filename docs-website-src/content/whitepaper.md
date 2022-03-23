---
title: "White Paper"
date: 2022-03-15T08:53:47-05:00
draft: false
layout: single
---

[download a pdf version of this white paper](/elevate/Elevating%20cPanel%20%26%20WHM_2022.pdf)

# Abstract

cPanel, L.L.C. has embraced the ELevate project [1], an open-source initiative by the AlmaLinux
OS Foundation (“AlmaLinux”) to help users perform upgrades between different Red Hat® Enterprise Linux®
(RHEL)-derivative distributions. This white paper captures the relevant details in evaluating the ELevate
process to upgrade a cPanel & WHM® server from a RHEL-derived distribution version 7.x to an
AlmaLinux distribution version 8.x. The intended audience for this paper are the decision-makers
who may be considering upgrading their cPanel & WHM servers to a different RHEL-based distribution.

# Introduction

> “ELevate is a project aimed to provide the ability to upgrade between major versions of RHEL-based distributions from 7.x to 8.x. It combines Red Hat’s Leapp framework with a community-created library and service for the migration metadata set required for it.” [1]

Upgrading from one distribution to another is challenging. To do so usually involves wiping a server and rebuilding it from the ground up or purchasing another server and migrating the data at additional cost. This forces a company to choose between living with an OS distribution that may no longer be the best choice for their business needs or going through a laborious upgrade process that may involve lengthy outages.
The ELevate project is designed to facilitate this process, enabling in-place upgrades between major versions of RHEL-based distributions. This provides a best-of-both-worlds scenario for sysadmins and infrastructure decision- makers. cPanel, L.L.C. has added custom tools to the ELevate tool chest that cover the cPanel & WHM aspects of the server upgrade process.

# ELevating your cPanel & WHM servers
Servers are core business infrastructure in today’s e-commerce economy. Server security, stability, and availability are critical for operational success in business today. As new operating systems are brought to market, and established OSs add new features, the landscape for server-based business operation changes. Being able to upgrade from one RHEL-derived OS to another without disrupting business operations lets a company optimize this critical infrastructure to stay competitive in an ever-changing technosphere.

## A. How is cPanel, L.L.C. leveraging the AlmaLinux ELevate project?
Changing the operating system that underlies a cPanel & WHM installation is not for the faint of heart. cPanel, L.L.C. supports the installation of cPanel & WHM on multiple RHEL-derived operating systems in order to support our customers’ ability to choose the operating system that best meets their business needs. Given the dynamic nature of this OS technosphere, cPanel, L.L.C. has leveraged the Elevate project’s tools for upgrading between RHEL-derived operating systems.

## B. Benefits and challenges of ELevating your cPanel & WHM servers
1. Benefits
    - The in-place upgrade process saves time and money. Not needing to provision new servers for   transfers or rebuild servers from the ground up removes significant barriers to upgrading your servers to a different operating system distribution.
    - The in-place upgrade process significantly reduces downtime based on our metrics. Our   initial cPanel & WHM server ELevation process took 90 minutes start to finish. Historically,  just transferring the accounts on a server in the same network to a new server has taken more than 3 hours. By avoiding the need to do such transfers, the upgrade process is more efficient  and has very low risk of incomplete migration.
    - All of the historical design decisions that led to the current system that supports your  business model are preserved in the upgrade process. This removes the complexities of   configuring an upgraded server to match the original server.
    - The option of easily moving away from an operating system that is out dated or near its   end-of-life means there’s no interruption in support and security updates from both cPanel,   L.L.C and upstream software providers.
2. Challenges
    - A cPanel&WHM server is a complex system that is highly customizable with 3rd-partypackages  and features that can be enabled/disabled. This rich environment complicates the upgrade  process to the point that, historically, it required starting from a fresh install of the new OS and rebuilding the cPanel & WHM server.
    - Treating a server OS upgrade as a task separate from maintaining a cPanel&WHS system  configuration complicates the upgrade process and risks loss of functionality.
3. The Solution
    - We built cPanel ELevate to meet these challenges, enabling an integrated, in-place upgrade  process. It manages the ELevate process end-to-end so that systems administrators can safely  and efficiently upgrade a cPanel & WHM server.

# How does the ELevate process work on cPanel & WHM servers

The ELevate project is designed to support in-place upgrades between major versions of RHEL-based distributions, specifically from a non-AlmaLinux RHEL distribution version 7.x to AlmaLinux 8.x. This works well for systems that are running basic applications. However, nothing about cPanel & WHM is basic. In order to support our customers who may want to upgrade their cPanel & WHM servers using the ELevate process, we have created a set of tools wrapped in a script that interacts with the ELevate tools to walk sysadmins through the upgrade process.

The cPanel ELevate script manages the ELevate OS upgrade process from a cPanel & WHM perspective. This involves gracefully stopping all processes and services that will be interrupted during the ELevate process; uninstalling any packages/services that expect to be installed on a fresh OS installation and reinstalling them once the ELevate process is complete; ensuring 3rd-party installations like Immunify360 and JetBackup are properly maintained through the upgrade process.

# Conclusion
Nobody knows a cPanel & WHM server as well as cPanel, L.L.C., so we’ve done the hard work for you. We’ve leveraged the open-source ELevate tools to support upgrading your servers with minimum cost, minimum time, and maximum confidence.

# Acknowledgment
We would like to acknowledge the excellent work done by the ELevate community to support the dynamic RHEL- derived Operating System technosphere, and The AlmaLinux OS Foundation for spearheading this project.

# Footnotes and Citations

[1] AlmaLinux ELevate Project - https://almalinux.org/elevate