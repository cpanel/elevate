# Welcome to the cPanel ELEVATE project.

This project builds on the [Alma Linux Elevate](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html) project, which leans heavily on the [LEAPP Project](https://leapp.readthedocs.io/en/latest/) created for in-place upgrades of RedHat based systems.

The Alma Linux Elevate project is very effective at upgrading the distro packages from CentOS 7 to AlmaLinux 8. However if you attempt to do this on a CentOS 7 based cPanel install, you will end up with a broken system.

## Some of the problems you might find include:
* x86_64 RPMs not in the primary CentOS repos are upgraded.
  * rpm -qa|grep el7.
* EA4 RPMs are incorrect
  * EA4 provides different dependencies and linkage on C7/A8
* cPanel binaries (cpanelsync) are invalid.
* 3rdparty repo packages are not upgraded (imunify 360, epel, ...).
* Manually installed Perl XS (arch) CPAN installs invalid.
* Manually installed PECL need re-build.
* Cpanel::CachedCommand is wrong/
* Cpanel::OS distro setting is wrong.
* MySQL might now not be upgradable (MySQL versions < 8.0 are not normally present on A8)


## Our current approach can be summarized as:
1. [Check for blockers](Known-blockers)
2. `yum update && reboot`
3. Analyze and remove software (not data) commonly installed on a cPanel system
4. [Execute AlmaLinux upgrade](https://wiki.almalinux.org/elevate/ELevate-quickstart-guide.html)
5. Re-install previoulsy removed software detected prior to upgrade. This might include:
  * cPanel (upcp)
  * EA4
  * MySQL variants
  * Distro Perl/PECL binary re-installs
6. Final reboot (assure all services are running on new binaries)

## RISKS
... yada
