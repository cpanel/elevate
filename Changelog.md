## ELevate Change Log

##### **2025-09-11** - version 71

* Fixed case CPANEL-49117: Remove experimental status for CL8->CL9 upgrades
* Fixed case RE-1604: Do not block the upgrade when the existing cPanel version is newer than what is stated in the major version's tier.

##### **2025-08-25** - version 70

* Fixed case RE-1602: Increate timeout in systemd unit file from default of 90s to 15min
* Fixed case RE-1573: Account for inherited domains when preserving PHP version

##### **2025-08-08** - version 69

* Fixed case RE-1599: Skip Imunify Component on Ubuntu
* Fixed case RE-1593: Add blocker for wp2 servers
* Fixed case RE-1595: Flush Cpanel::OS cache before rebooting to upgrade OS
* Fixed case RE-1589: Add 'alt-common' to list of vetted yum repos
* Fix documentation typo in blockers.

##### **2025-06-25** - version 68

* Fixed case RE-1309: Add experimental support for CL8->CL9 distro upgrades.

##### **2025-06-16** - version 67

* Fixed case RE-1555: Ensure that Perl 5.42 get rebuild on the first upcp
* Fixed case RE-1568: Set update tier to release on C7->A8 upgrades

##### **2025-05-28** - version 66

* Fixed case RE-1531: Add support for MySQL 8.4 for a8->a9 distro upgrades
* Fixed case RE-1535: Add blocker for when ifcfg files are missing the TYPE parameter on upgrades from A8->A9
* Fixed case RE-1500: Ensure that the correct package signing keys are installed if KernelCare is detected.
* Fixed case RE-1511: Add support for the platform360-cpanel repo
* Fixed case RE-1461: Move EA4 post_distro_upgrade step to after first upcp.
* Fixed case RE-1501: Only emit warning about absolute symlinks if there are absolute symlinks
* Fixed case RE-1442: Ensure plugins=1 is set in yum.conf before starting CloudLinux upgrades
* Fixed case RE-1442: Have Blockers emit an error to the logs instead of a warning

##### **2025-04-23** - version 65

* Fixed case RE-1397: Add support for named tiers and have a8->a9 upgrades use it
* Fixed case RE-1416: Fixed elevation on Ubuntu with Nginx installed.
* Revert "Pass '--target 8.9' to leapp upgrade for c7->a8 upgrades" Upstream has corrected this.

##### **2025-04-03** - version 64

* Fixed case RE-1450: Pass '--target 8.9' to leapp upgrade for c7->a8 upgrades to address instability with upgrades to 8.10

##### **2025-04-02** - version 63

* Alma 8->9 is no longer Experimental.
* Fixed case RE-1391: Support elevation of AlmaLinux 8 with JetBackup installed.
* Fixed case RE-1388: Support systems with SHA1-signed packages.
* Fixed case RE-1395: Change ordering of components so that the WPToolkit component runs sooner during the post distro upgrade stage.
* Fixed case RE-1395: Add component to disable securetmp during u20->u22 upgrades
* Fixed case RE-1371: Add support for Imunify 360's hardened PHP during A8->A9 upgrades
* Fixed case RE-1386: Work around encoding bug in Leapp.
* Fixed case RE-1387: Install VDO tools to satisfy a Leapp dependency on EL8-based systems.

##### **2025-03-13** - version 62

* Fixed case RE-1389: Block elevation of AlmaLinux 8 with JetBackup installed (until we support that).
* Fixed case RE-1383: Fix elevate to work when MariaDB 11.4 is installed.
* Fixed case RE-1155: Add support for A8->A9 distro upgrades
* Fixed case RE-1348: Preserve exim config files during elevate.
* Fixed case RE-1356: Ignore warnings on Ubuntu about deprecated storage of GPG keys.
* Fixed case RE-1262: Default MySQL/MariaDB database checks to a UTF-8 character set.

##### **2025-02-06** - version 61

* Fixed case RE-1179: Do not restore config files for dropped packages. Especially on Ubuntu

##### **2025-01-15** - version 60

* Fixed case RE-1160: Remove experimental status for u20->u22 upgrades
* Fixed case RE-800: Update --help to be more Ubuntu friendly
* Fixed case RE-945: Update strings to be language agnostic for Ubuntu
* Fixed case RE-943: Add component to manage port 1022 for ELevations that rely on the do-release-upgrade script to perform the OS upgrade
* Fixed case RE-670: Add Ubuntu support for checking that the system controls its own boot process.

##### **2024-12-02** - version 59

* Fixed case RE-664: Add initial support for Ubuntu 20 to Ubuntu 22 upgrades
* Fixed case RE-996: Add auto retry for package manager based commands
* Fixed case RE-974: Only perform the check to determine if MySQL has any corrupted databases while in start mode
* Fixed case RE-672: Update DiskSpace check to account for Ubuntu
* Fixed case RE-668: Add support for Jetbackup in U20->U22

##### **2024-11-19** - version 58

* Fixed case RE-964: Avoid Perl error in 'Elevate::Components::Repositories'
* Fixed case RE-952: Add 'sys-snap' to the list of packages that the PackageRestore component handles
* Fail with a more specific error about what executable is not available

##### **2024-11-07** - version 57

* Fixed case RE-846: Re-install Softaculous after upgrade.
* Fixed case RE-934: Ensure final dnf update is executed
* Fixed case RE-844: Add support for the hgdedi repository and remove obsolete packages it provides:  eigid and quickinstall.
* Fixed case RE-252: Refactor package manager logic
* Fixed case RE-782: Verify integrity of databases before elevation.
* Fixed case RE-845: Add 'ul' and 'ul_*' to the list of vetted repositories.

##### **2024-10-28** - version 56

* Fixed case RE-812: Fix elevate failures stemming from having a customized epel.repo file.
* Fixed case RE-575: Support running elevate on systems that have the Acronis backup agent installed.
* Fixed case RE-652: Attempt to resolve duplicate RPMs found prior to upgrade.
* Fixed case RE-723: Use mv and cp from File::Copy instead of copy and move
* Fixed case RE-862: Ensure Imunify upgrade is not executing before attempting to uninstall it
* Fixed case RE-673: Merge blockers into components

##### **2024-09-30** - version 55
* Add support for "cl7h" (Cloud Linux 7 Hybrid) repository.

##### **2024-09-23** - version 54

* Fixed case RE-697: Make 'upgrade_to_pretty_name' an Elevate::OS key
* Fixed case RE-603: Add a whitelist for some legacy pacakges without a repo
* Fixed case RE-695: Turn `--no-leapp` into a more generic `--upgrade-distro-manually` option, but continue to recognize `--no-leapp` as an alias for it.
* Fixed case RE-217: Re-work Leapp failure handling to report all inhibitors.

##### **2024-08-29** - version 53

* Fixed case RE-574: Ensure that system with net-snmp installed will have it installed post-elevate.
* Fixed case RE-492: Where appropriate, mention "MariaDB" instead of "MySQL".

##### **2024-08-22** - version 52

* Fixed case RE-43: No longer block on Panopta or FortiMonitor
* Fixed case RE-247: Permit leapp to handle updates to the EPEL repository.
* Fixed case RE-102: Attempt to upgrade PostgreSQL during ELevate.
* Fixed case RE-662: Fix text in failure advice when MySQL restore fails

##### **2024-08-07** - version 51

* Fixed case RE-543: Restore my.cnf after installing the database server during post_leapp
* Fixed case RE-611: Move logic to gather and store php usage to a component
* Fixed case RE-499: Fix restore logic for config files of packages provided by EA4
* Fixed case RE-614: Add 'check_detected_devices_and_drivers' to list of inhibitors to ignore in the leapp preupgrade check to prepare for upstream leapp version 0.19.0
* Fixed case RE-34: Unblock remote MySQL blocker by temporarily disabling the remote profile during the upgrade.

##### **2024-08-01** - version 50

* Fixed case RE-514: Check whether leapp can control the boot process before significant and irreversible changes are applied to the system.
* Fixed case RE-113: Stop using the --noscripts flag when erasing wp-toolkit-cpanel in pre-leapp stage.
* Fixed case RE-404: Do not log output of Imunify license check
* Fixed case RE-502: Enable elevate on systems with the R1Soft Backup Agent installed.
* Fixed case RE-544: Do not cleanup database packages if the database is provided by CloudLinux
* Fixed case RE-535: Have check that Imunify 360 provides hardened PHP ensure that the 'ea-cpanel-tools' package is provided by the CloudLinux repository

##### **2024-07-23** - version 49

* Fixed Case RE-72: Update PECL check to run before EA in pre_leapp phase; use php_get_installed_versions to determine EA PHP package versions.
* Fixed Case RE-452: Add blocker for duplicate repo IDs

##### **2024-07-16** - version 48

* Fixed case RE-538: Have ELS component always remove the ELS repo files if they exist

##### **2024-07-11** - version 47

* Fixed case RE-542:  Add jetapps-* to the list of vetted repos

##### **2024-07-10** - version 46

* Re-enable cloudlinux elevations after bugs related to dnf/spacewalk were addressed in upstream leapp.
* Fixed case RE-361: Make it more clear why yum makecache failures are a problem
* Fixed case RE-466: Improve error output when the script aborts due to a failed external command.
* Fixed case RE-534: Don't block on ELS rollout repo slots
* Fixed case RE-420: Block when packages are installed from a disabled repo
* Fixed case RE-505: Do not allow check to run in the middle of an elevation

##### **2024-07-03** - version 45

* Case RE-500: Disable cloudlinux elevations until bugs related to dnf/spacewalk are addressed in upstream leapp.

##### **2024-07-01** - version 44

* Fixed case RE-368: Remove 'ELS for CentOS 7' prior to elevation.

##### **2024-06-26** - version 43

* Fixed case RE-403: Use 'CloudLinux_8' target to backup EA4 profile on servers with Imunify 360 installed and providing the hardened PHP feature

##### **2024-06-25** - version 42

* Fixed case RE-450: Set locale environment variables to "C" before elevating.
* Fixed case RE-475: Teach wait_for_leapp_completion() about the no-leapp option
* Fixed case RE-336: Removed python36 blocker on CloudLinux/CentOS 7
* Fixed case RE-337: Convert multiple NICs blocker to component

##### **2024-06-12** - version 41

* Fixed case RE-338: No longer blocks if there are unfinished yum transactions.

##### **2024-06-05** - version 40

* Fixed case RE-343: Runs &quot;yum clean all&quot; and retries &quot;yum makecache&quot; if it had initially failed.

##### **2024-05-29** - version 39

* Fixed case RE-132: Have pre_leapp component remove packages that leapp will remove.
* Fixed case RE-373: Add blocker for an invalid Imunify license.

##### **2024-05-15** - version 38

* Fixed case RE-134: Have script block if mount -a fails to exit cleanly.
* Fixed case RE-313: Enhance EA4 blocker so that it only blocks on installed PHP versions that are not provided by Imunify 360 and are actively in use by domains on the server.
* Revert RE-306: It is no longer necessary to block if /usr is a separate private mount point now it has been fixed in the upstream leapp project.

##### **2024-05-06** - version 37

* Fixed case RE-306: Add blocker if &#39;/usr&#39; is a separate private mount point.

##### **2024-04-30** - version 36

* Fixed case RE-78: Convert CCS blocker to component.
* Fixed case RE-167: Updated the documentation about the blockers.
* Fixed case RE-261: In the event of a blocker found by performing a leapp preupgrade, direct the user to the /var/log/leapp directory to find more information.

##### **2024-04-23** - version 35

* Fixed case RE-122: Move logic for prepping cPanel for leapp to a component.
* Fixed case RE-218: Remove support for elevating to Rocky Linux.
* Fixed case RE-305: Do not delay 10 minutes when elevate_leap_fail_continue is put in place.
* Fixed case RE-318: Fix DNS blocker to check the systems name server type.

##### **2024-04-16** - version 34

* Fixed case RE-171: Provide auto-upgrade mechanism for out-of-date MySQL/MariaDB versions (installed via cPanel, not CloudLinux).
* Fixed case RE-224: Added in more checks to report potential failures of LEAPP.
* Fixed case RE-260: Ensure all system calls are executable absolute paths.

##### **2024-04-09** - version 33

* Removed experimental tag from Cloud Linux 7->8

##### **2024-04-02** - version 32

* Fixed case RE-250: Modularize stage logic.
* Fixed case RE-274: Update string in last chance message to inform the user of the correct OS that is being updated.

##### **2024-03-29** - version 31
* Fixed case RE-275: Add command line arg --leappbeta to use the leapp beta repos

##### **2024-03-27** - version 30

* Fixed case RE-265: Validate script can execute start option before parsing upgrade_to option.

##### **2024-03-26** - version 29

* Fixed case CPANEL-41659: Change to Let&#39;s Encrypt if Sectigo is the AutoSSL provider.
* Fixed case RE-83: Block if the grub2-pc package is not installed or if the grub.cfg file is missing.
* Fixed case RE-138: Ensure upcp and backups cannot run at the same time as ELevate.
* Fixed case RE-213: Convert logic to remove modules that do not convert into component.
* Fixed case RE-223: Also block on the &#39;leapp preupgrade&#39; ERRORS.
* Fixed case RE-249: Ensure proper OS detection on servers that have been previously elevated.

##### **2024-03-13** - version 28

* Fixed case RE-153: Add support for CL MySQL.
* Fixed case RE-172: Remove blocker to check if the system is up to date.

##### **2024-03-05** - version 27

* Fixed case RE-89: Improved blocker yum reporting.
* Fixed case RE-228: Do not copy the stage file to the success file until we notify the user that the process succeeded.

##### **2024-02-27** - version 26

* Fixed case RE-90: Add a pre-flight leapp check when checking for upgrade blockers.
* Fixed case RE-173: Add blocker for invalid CloudLinux licenses.
* Fixed case RE-188: Improve the check for PostgreSQL users to be more efficient and not throw an error if the feature is disabled for any of the users.

##### **2024-02-21** - version 25

* Fixed case RE-206: Do not remove &#39;alt-pcre802&#39; post elevate to avoid breaking Cloudlinux ea-php51/ea-php52

##### **2024-02-19** - version 24

* Fixed case RE-18: Add initial "Experimental" support for Elevating from CL7 to CL8.
* Fixed case RE-186: Document manual-reboots flag in help text.

##### **2024-02-12** - version 23

* Fixed case RE-2: Always show ELevate MOTD when ELevate is running.
* Fixed case RE-112: Set PermitRootLogin for sshd to &#39;yes&#39; if not explicitly set in the configuration file so that the behavior does not change after the upgrade.

##### **2024-02-05** - version 22

* RE-55: Document possible statuses in /var/cpanel/elevate.
* RE-56: Removed the simple version check from the BEGIN block of the script since this happens during the check operation.
* RE-57: Improved command line option validation
* RE-71: Add blocker for start mode if bin/backup or scripts/upcp is currently executing.
* RE-38: Restore config files for packages provided by the EA4 repo.

##### **2024-01-25** - version 21

* Get fix-cpanel-perl to run after distro change without breaking perl.
* Update elevate for jetbackup to be aware of JetBackup 5.3

##### **2024-01-22** - version 20

* #338 - Improve warning and add prompt before starting the upgrade process
* #327 - Block with cPanel accounts have databases on postgresql.
* RE-93 - Do not return from EA4 blocker check prematurely
* RE-13 - Fix typo in help docs. s/convertion/conversion/

##### **2024-01-16** - version 19

* #337 - Add blocker if cPanel is not running version 110
* #341 - Use canonical_dump() when building JSON for repo blocker reports
* #348 - Incorporate running --check into running --start

##### **2024-01-09** - version 18

* #332 - Suppress additional checks when run with --check --no-leapp

##### **2023-12-20** - version 17

* Encode blocked repos to assist with enabling support for future elevations

##### **2023-12-11** - version 16

* Add repo allowance for vzzo custom migrations - ct-preset

##### **2023-11-29** - version 15

* Enable powertools after upgrade
* Disable cpanel-plugins repo after upgrade for initial dnf update

##### **2023-09-09** - version 14

* Use leapp answerfile instead of userchoices. Fixes #216
* Check MySQL status before starting upgrade. Fixes #287
* Vet digitalocean-agent repo.
* Vet elasticsearch-7.x repo.
* Fixup BootKernel error message. Fixes #305
* Add EA4-c$releasever to vetted repo list.
* Improve stop and disable function in Systemctl logic. Fixes #309
* cpanel-elevate stage 4 during mysql upgrade improved success detection. Fixes #311
* Add support for non-leapp upgrades. Fixes #302

##### **2023-06-01** - version 13

* Clear Cpanel::OS' $instance cache after upgrade to rocky 8. Fixes false positive failure.
* Remove duped final_notifications display on final success.
* Add documentation fixes for NIC rename advice
* Pass through the "check only" mode status properly. - Fixes Linode upgrade failures.
* Fix for "Wide character warning"

##### **2023-05-18** - version 12

* #170 - preserve and restore /etc/my.cnf after LEAPP upgrade and mysql restore.
* Fix MOTD message being blank due to fatpacker stripping it out.
* Assure LANG=C on all elevate systems.
* Add logic to autofix absolute symlinks in / which blocks leapp upgrades.
* If we run check-upgrade to a specific flavor, suggest to run the correct command.
* Fix bad getopt caller, that is delegated to cpev.
* Improved error message when calling missing functions.
* Impose maximum LTS version, change version recommendation to v110.
* Add new imunify repos to known list.

##### **2023-05-08** - version 11

* Block use of this product if cPanel unlicensed.
* Add blocker for presence of python36 RPMs.
* Bugfix due to bad caller of Base in InvalidYumRepo check. Fixes #252

##### **2023-05-03** - version 10

* Fix more bad ssystem calls
* Block if the running and boot kernels differ

##### **2023-04-27** - version 9

* Fix for #243. restore XS was crashing post upgrade.

##### **2023-04-26** - version 8
There are no user facing changes in this release. We have re-designed the development
process to make it faster and easier for us to develop this product.

##### **2023-04-10** - version 7

* Fix issue #151: Do not block on installed repos if no packages are installed from them.
* Remove source, debuginfo and vault entries from vetted repos.
* Stop restore_perl_xs from running dnf needlessly which led to a crash.
* Track which version of cpanel-elevate upgraded the local distro.
* Change recommended policy to direct people to cPanel support for issues.

##### **2023-03-13** - version 6

* If the file /var/cpanel/elevate-noc-recommendations exists, present the user with the contents of the file and confirm if they want to proceed.
* Exempt EA4 OpenSSL devel packages from blocker
* Ensure `net.ifnames=0` is added to the GRUB env if not mentioned there.

##### **2023-02-14** - version 5

###### User Facing

* Correct spelling of "Alamlinux"
* Add a doc notification for OVH monitoring
* Add a warning/blocker for OVH monitoring
* Bump copyright to 2023
* Check and fix grub for net.ifnames=0 post leapp upgrade.

##### **2022-12-20** - version 4

###### User Facing

* Increase the disk requirements for upgrade +1GB to allow more space in the leapp container.
* #149 - Cleanup stage_file before storing data. Fixes inaccurate EA4 blocker cache issue.

##### **2022-12-12** - version 3

###### User Facing

* Do not use "ERROR" for successful notifications.
* Fine tune the logging colors and only use it for the keyword.
* Fix crash when restoring imunify if it was not present at start.
* Do not block when detecting kernel update required.
* Better hints for MySQL upgrade needed.
* Handle recovery after manual intervention if leapp process fails. Give better advice to users when it happens.
* Stop warning about postgresql 9 now CCS supports 10

###### Internal:

* Simplify v# release process.
* Modularize blocker tests.

##### **2022-11-16** - version 2

###### User Facing

* Fixed bug in logic for version check which was detecting a new version incorrectly.
* Recommend proper MariaDB version for cPanel v110

###### Internal:

* Allow testing using alternative update URLs

##### **2022-10-17** - version 1

###### User Facing

* Fix run_once entry names in stage file
* Work around use of /boot/grub/ in some providers
* Implement self-update mechanism for elevate-cpanel
* Allow upgrades when using MySQL from mysql-community.repo
* Allow upgrades to Rocky Linux 8
* AlmaLinux capitalization
* Begin versioning and a formal changelog
* Backup EA profile to a temporary file on --check

###### Internal:

* read_stage_file() can read specific data
* run_once is now a method

##### **2022-10-07** - version 0

* See git log for more history.
