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

## **2024-02-12** - version 23

* Fixed case RE-2: Always show ELevate MOTD when ELevate is running.
* Fixed case RE-112: Set PermitRootLogin for sshd to &#39;yes&#39; if not explicitly set in the configuration file so that the behavior does not change after the upgrade.

## **2024-02-05** - version 22

* RE-55: Document possible statuses in /var/cpanel/elevate.
* RE-56: Removed the simple version check from the BEGIN block of the script since this happens during the check operation.
* RE-57: Improved command line option validation
* RE-71: Add blocker for start mode if bin/backup or scripts/upcp is currently executing.
* RE-38: Restore config files for packages provided by the EA4 repo.

## **2024-01-25** - version 21

* Get fix-cpanel-perl to run after distro change without breaking perl.
* Update elevate for jetbackup to be aware of JetBackup 5.3

## **2024-01-22** - version 20

* #338 - Improve warning and add prompt before starting the upgrade process
* #327 - Block with cPanel accounts have databases on postgresql.
* RE-93 - Do not return from EA4 blocker check prematurely
* RE-13 - Fix typo in help docs. s/convertion/conversion/

## **2024-01-16** - version 19

* #337 - Add blocker if cPanel is not running version 110
* #341 - Use canonical_dump() when building JSON for repo blocker reports
* #348 - Incorporate running --check into running --start

## **2024-01-09** - version 18

* #332 - Suppress additional checks when run with --check --no-leapp

## **2023-12-20** - version 17

* Encode blocked repos to assist with enabling support for future elevations

## **2023-12-11** - version 16

* Add repo allowance for vzzo custom migrations - ct-preset

## **2023-11-29** - version 15

* Enable powertools after upgrade
* Disable cpanel-plugins repo after upgrade for initial dnf update

## **2023-09-09** - version 14

* Use leapp answerfile instead of userchoices. Fixes #216
* Check MySQL status before starting upgrade. Fixes #287
* Vet digitalocean-agent repo.
* Vet elasticsearch-7.x repo.
* Fixup BootKernel error message. Fixes #305
* Add EA4-c$releasever to vetted repo list.
* Improve stop and disable function in Systemctl logic. Fixes #309
* cpanel-elevate stage 4 during mysql upgrade improved success detection. Fixes #311
* Add support for non-leapp upgrades. Fixes #302

## **2023-06-01** - version 13

* Clear Cpanel::OS' $instance cache after upgrade to rocky 8. Fixes false positive failure.
* Remove duped final_notifications display on final success.
* Add documentation fixes for NIC rename advice
* Pass through the "check only" mode status properly. - Fixes Linode upgrade failures.
* Fix for "Wide character warning"

## **2023-05-18** - version 12

* #170 - preserve and restore /etc/my.cnf after LEAPP upgrade and mysql restore.
* Fix MOTD message being blank due to fatpacker stripping it out.
* Assure LANG=C on all elevate systems.
* Add logic to autofix absolute symlinks in / which blocks leapp upgrades.
* If we run check-upgrade to a specific flavor, suggest to run the correct command.
* Fix bad getopt caller, that is delegated to cpev.
* Improved error message when calling missing functions.
* Impose maximum LTS version, change version recommendation to v110.
* Add new imunify repos to known list.

## **2023-05-08** - version 11

* Block use of this product if cPanel unlicensed.
* Add blocker for presence of python36 RPMs.
* Bugfix due to bad caller of Base in InvalidYumRepo check. Fixes #252

## **2023-05-03** - version 10

* Fix more bad ssystem calls
* Block if the running and boot kernels differ

## **2023-04-27** - version 9

* Fix for #243. restore XS was crashing post upgrade.

## **2023-04-26** - version 8
There are no user facing changes in this release. We have re-designed the development
process to make it faster and easier for us to develop this product.

## **2023-04-10** - version 7

* Fix issue #151: Do not block on installed repos if no packages are installed from them.
* Remove source, debuginfo and vault entries from vetted repos.
* Stop restore_perl_xs from running dnf needlessly which led to a crash.
* Track which version of cpanel-elevate upgraded the local distro.
* Change recommended policy to direct people to cPanel support for issues.

## **2023-03-13** - version 6

* If the file /var/cpanel/elevate-noc-recommendations exists, present the user with the contents of the file and confirm if they want to proceed.
* Exempt EA4 OpenSSL devel packages from blocker
* Ensure `net.ifnames=0` is added to the GRUB env if not mentioned there.

## **2023-02-14** - version 5

### User Facing

* Correct spelling of "Alamlinux"
* Add a doc notification for OVH monitoring
* Add a warning/blocker for OVH monitoring
* Bump copyright to 2023
* Check and fix grub for net.ifnames=0 post leapp upgrade.

## **2022-12-20** - version 4

### User Facing

* Increase the disk requirements for upgrade +1GB to allow more space in the leapp container.
* #149 - Cleanup stage_file before storing data. Fixes inaccurate EA4 blocker cache issue.

## **2022-12-12** - version 3

### User Facing

* Do not use "ERROR" for successful notifications.
* Fine tune the logging colors and only use it for the keyword.
* Fix crash when restoring imunify if it was not present at start.
* Do not block when detecting kernel update required.
* Better hints for MySQL upgrade needed.
* Handle recovery after manual intervention if leapp process fails. Give better advice to users when it happens.
* Stop warning about postgresql 9 now CCS supports 10

### Internal:

* Simplify v# release process.
* Modularize blocker tests.

## **2022-11-16** - version 2

### User Facing

* Fixed bug in logic for version check which was detecting a new version incorrectly.
* Recommend proper MariaDB version for cPanel v110

### Internal:

* Allow testing using alternative update URLs

## **2022-10-17** - version 1

### User Facing

* Fix run_once entry names in stage file
* Work around use of /boot/grub/ in some providers
* Implement self-update mechanism for elevate-cpanel
* Allow upgrades when using MySQL from mysql-community.repo
* Allow upgrades to Rocky Linux 8
* AlmaLinux capitalization
* Begin versioning and a formal changelog
* Backup EA profile to a temporary file on --check

### Internal:

* read_stage_file() can read specific data
* run_once is now a method

## **2022-10-07** - version 0

* See git log for more history.
