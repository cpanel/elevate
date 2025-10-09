# Elevate::OS - os.dump

## Why this file?

This file provides a rendering of all supported Elevate::OS values.

The goal is to provide a comprehensive view of the impact of a change for each commit.

Some values are defined in `virtual` classes. Changing a boolean value for example could impact more distros than expected.

This file provides the **developer** and the **reviewer** with the ability to better **understand** the *scope* of a **Elevate::OS change**.

## When do I update this file?

Each commit introducing changes to Elevate::OS should update this file. Automated tools exist to detect and update it automatically.

When adding a new file to Elevate::OS namespace or altering the existing ones with:
 - new values
 - removed values
 - altered values

## How do I update this file?

By running the unit test `t/Elevate-OS_detect_changes.t`, this file will be updated automatically. The test will fail if changes are detected. This allows cplint and smokers to block merges when this file needs updating.

```
yath -v t/Elevate-OS_detect_changes.t
```

# A dump of all keys:


## archive_dir

---
```
+-------------+------------+-------+------------------------------+
| key         | distro     | major | archive_dir                  |
+-------------+------------+-------+------------------------------+
| archive_dir | AlmaLinux  | 8     | "CentOS7-to-AlmaLinux8"      |
| archive_dir | CentOS     | 7     | undef                        |
| archive_dir | CloudLinux | 7     | undef                        |
| archive_dir | CloudLinux | 8     | "CloudLinux7-to-CloudLinux8" |
| archive_dir | Ubuntu     | 20    | undef                        |
| archive_dir | Ubuntu     | 22    | "Ubuntu20-to-Ubuntu22"       |
+-------------+------------+-------+------------------------------+
```
---


## bootloader_config_method

---
```
+--------------------------+------------+-------+--------------------------+
| key                      | distro     | major | bootloader_config_method |
+--------------------------+------------+-------+--------------------------+
| bootloader_config_method | AlmaLinux  | 8     | "grubby"                 |
| bootloader_config_method | CentOS     | 7     | "grubby"                 |
| bootloader_config_method | CloudLinux | 7     | "grubby"                 |
| bootloader_config_method | CloudLinux | 8     | "grubby"                 |
| bootloader_config_method | Ubuntu     | 20    | "grub-mkconfig"          |
| bootloader_config_method | Ubuntu     | 22    | "grub-mkconfig"          |
+--------------------------+------------+-------+--------------------------+
```
---


## default_upgrade_to

---
```
+--------------------+------------+-------+--------------------+
| key                | distro     | major | default_upgrade_to |
+--------------------+------------+-------+--------------------+
| default_upgrade_to | AlmaLinux  | 8     | "AlmaLinux"        |
| default_upgrade_to | CentOS     | 7     | "AlmaLinux"        |
| default_upgrade_to | CloudLinux | 7     | "CloudLinux"       |
| default_upgrade_to | CloudLinux | 8     | "CloudLinux"       |
| default_upgrade_to | Ubuntu     | 20    | "Ubuntu"           |
| default_upgrade_to | Ubuntu     | 22    | "Ubuntu"           |
+--------------------+------------+-------+--------------------+
```
---


## disable_mysql_yum_repos

---
```
+-------------------------+------------+-------+-----------------------------+
| key                     | distro     | major | disable_mysql_yum_repos     |
+-------------------------+------------+-------+-----------------------------+
| disable_mysql_yum_repos | AlmaLinux  | 8     | [\n                         |
|                         |            |       |   "MariaDB102.repo",\n      |
|                         |            |       |   "MariaDB103.repo",\n      |
|                         |            |       |   "MariaDB105.repo",\n      |
|                         |            |       |   "MariaDB106.repo",\n      |
|                         |            |       |   "Mysql57.repo",\n         |
|                         |            |       |   "Mysql80.repo",\n         |
|                         |            |       |   "mysql-community.repo",\n |
|                         |            |       | ]                           |
|                         |            |       |                             |
| disable_mysql_yum_repos | CentOS     | 7     | [\n                         |
|                         |            |       |   "MariaDB102.repo",\n      |
|                         |            |       |   "MariaDB103.repo",\n      |
|                         |            |       |   "MariaDB105.repo",\n      |
|                         |            |       |   "MariaDB106.repo",\n      |
|                         |            |       |   "Mysql57.repo",\n         |
|                         |            |       |   "Mysql80.repo",\n         |
|                         |            |       |   "mysql-community.repo",\n |
|                         |            |       | ]                           |
|                         |            |       |                             |
| disable_mysql_yum_repos | CloudLinux | 7     | [\n                         |
|                         |            |       |   "MariaDB102.repo",\n      |
|                         |            |       |   "MariaDB103.repo",\n      |
|                         |            |       |   "MariaDB105.repo",\n      |
|                         |            |       |   "MariaDB106.repo",\n      |
|                         |            |       |   "Mysql57.repo",\n         |
|                         |            |       |   "Mysql80.repo",\n         |
|                         |            |       |   "mysql-community.repo",\n |
|                         |            |       | ]                           |
|                         |            |       |                             |
| disable_mysql_yum_repos | CloudLinux | 8     | [\n                         |
|                         |            |       |   "MariaDB102.repo",\n      |
|                         |            |       |   "MariaDB103.repo",\n      |
|                         |            |       |   "MariaDB105.repo",\n      |
|                         |            |       |   "MariaDB106.repo",\n      |
|                         |            |       |   "Mysql57.repo",\n         |
|                         |            |       |   "Mysql80.repo",\n         |
|                         |            |       |   "mysql-community.repo",\n |
|                         |            |       | ]                           |
|                         |            |       |                             |
| disable_mysql_yum_repos | Ubuntu     | 20    | undef                       |
| disable_mysql_yum_repos | Ubuntu     | 22    | undef                       |
+-------------------------+------------+-------+-----------------------------+
```
---


## ea_alias

---
```
+----------+------------+-------+-----------------+
| key      | distro     | major | ea_alias        |
+----------+------------+-------+-----------------+
| ea_alias | AlmaLinux  | 8     | "CentOS_9"      |
| ea_alias | CentOS     | 7     | "CentOS_8"      |
| ea_alias | CloudLinux | 7     | "CloudLinux_8"  |
| ea_alias | CloudLinux | 8     | "CloudLinux_9"  |
| ea_alias | Ubuntu     | 20    | "Ubuntu_22.04"  |
| ea_alias | Ubuntu     | 22    | "xUbuntu_24.04" |
+----------+------------+-------+-----------------+
```
---


## el_package_regex

---
```
+------------------+------------+-------+------------------+
| key              | distro     | major | el_package_regex |
+------------------+------------+-------+------------------+
| el_package_regex | AlmaLinux  | 8     | "el8"            |
| el_package_regex | CentOS     | 7     | "el7"            |
| el_package_regex | CloudLinux | 7     | "el7"            |
| el_package_regex | CloudLinux | 8     | "el8"            |
| el_package_regex | Ubuntu     | 20    | undef            |
| el_package_regex | Ubuntu     | 22    | undef            |
+------------------+------------+-------+------------------+
```
---


## elevate_rpm_url

---
```
+-----------------+------------+-------+-----------------------------------------------------------------------------+
| key             | distro     | major | elevate_rpm_url                                                             |
+-----------------+------------+-------+-----------------------------------------------------------------------------+
| elevate_rpm_url | AlmaLinux  | 8     | "https://repo.almalinux.org/elevate/elevate-release-latest-el8.noarch.rpm"  |
| elevate_rpm_url | CentOS     | 7     | "https://repo.almalinux.org/elevate/elevate-release-latest-el7.noarch.rpm"  |
| elevate_rpm_url | CloudLinux | 7     | "https://repo.cloudlinux.com/elevate/elevate-release-latest-el7.noarch.rpm" |
| elevate_rpm_url | CloudLinux | 8     | "https://repo.cloudlinux.com/elevate/elevate-release-latest-el8.noarch.rpm" |
| elevate_rpm_url | Ubuntu     | 20    | undef                                                                       |
| elevate_rpm_url | Ubuntu     | 22    | undef                                                                       |
+-----------------+------------+-------+-----------------------------------------------------------------------------+
```
---


## expected_post_upgrade_major

---
```
+-----------------------------+------------+-------+-----------------------------+
| key                         | distro     | major | expected_post_upgrade_major |
+-----------------------------+------------+-------+-----------------------------+
| expected_post_upgrade_major | AlmaLinux  | 8     | 9                           |
| expected_post_upgrade_major | CentOS     | 7     | 8                           |
| expected_post_upgrade_major | CloudLinux | 7     | 8                           |
| expected_post_upgrade_major | CloudLinux | 8     | 9                           |
| expected_post_upgrade_major | Ubuntu     | 20    | 22                          |
| expected_post_upgrade_major | Ubuntu     | 22    | 24                          |
+-----------------------------+------------+-------+-----------------------------+
```
---


## has_crypto_policies

---
```
+---------------------+------------+-------+---------------------+
| key                 | distro     | major | has_crypto_policies |
+---------------------+------------+-------+---------------------+
| has_crypto_policies | AlmaLinux  | 8     | 1                   |
| has_crypto_policies | CentOS     | 7     | 0                   |
| has_crypto_policies | CloudLinux | 7     | 0                   |
| has_crypto_policies | CloudLinux | 8     | 1                   |
| has_crypto_policies | Ubuntu     | 20    | 0                   |
| has_crypto_policies | Ubuntu     | 22    | 0                   |
+---------------------+------------+-------+---------------------+
```
---


## has_imunify_ea_alias

---
```
+----------------------+------------+-------+----------------------+
| key                  | distro     | major | has_imunify_ea_alias |
+----------------------+------------+-------+----------------------+
| has_imunify_ea_alias | AlmaLinux  | 8     | 1                    |
| has_imunify_ea_alias | CentOS     | 7     | 1                    |
| has_imunify_ea_alias | CloudLinux | 7     | 0                    |
| has_imunify_ea_alias | CloudLinux | 8     | 0                    |
| has_imunify_ea_alias | Ubuntu     | 20    | 0                    |
| has_imunify_ea_alias | Ubuntu     | 22    | 0                    |
+----------------------+------------+-------+----------------------+
```
---


## imunify_ea_alias

---
```
+------------------+------------+-------+------------------+
| key              | distro     | major | imunify_ea_alias |
+------------------+------------+-------+------------------+
| imunify_ea_alias | AlmaLinux  | 8     | "CloudLinux_9"   |
| imunify_ea_alias | CentOS     | 7     | "CloudLinux_8"   |
| imunify_ea_alias | CloudLinux | 7     | undef            |
| imunify_ea_alias | CloudLinux | 8     | undef            |
| imunify_ea_alias | Ubuntu     | 20    | undef            |
| imunify_ea_alias | Ubuntu     | 22    | undef            |
+------------------+------------+-------+------------------+
```
---


## is_apt_based

---
```
+--------------+------------+-------+--------------+
| key          | distro     | major | is_apt_based |
+--------------+------------+-------+--------------+
| is_apt_based | AlmaLinux  | 8     | 0            |
| is_apt_based | CentOS     | 7     | 0            |
| is_apt_based | CloudLinux | 7     | 0            |
| is_apt_based | CloudLinux | 8     | 0            |
| is_apt_based | Ubuntu     | 20    | 1            |
| is_apt_based | Ubuntu     | 22    | 1            |
+--------------+------------+-------+--------------+
```
---


## is_experimental

---
```
+-----------------+------------+-------+-----------------+
| key             | distro     | major | is_experimental |
+-----------------+------------+-------+-----------------+
| is_experimental | AlmaLinux  | 8     | 0               |
| is_experimental | CentOS     | 7     | 0               |
| is_experimental | CloudLinux | 7     | 0               |
| is_experimental | CloudLinux | 8     | 0               |
| is_experimental | Ubuntu     | 20    | 0               |
| is_experimental | Ubuntu     | 22    | 0               |
+-----------------+------------+-------+-----------------+
```
---


## is_supported

---
```
+--------------+------------+-------+--------------+
| key          | distro     | major | is_supported |
+--------------+------------+-------+--------------+
| is_supported | AlmaLinux  | 8     | 1            |
| is_supported | CentOS     | 7     | 1            |
| is_supported | CloudLinux | 7     | 1            |
| is_supported | CloudLinux | 8     | 1            |
| is_supported | Ubuntu     | 20    | 1            |
| is_supported | Ubuntu     | 22    | 1            |
+--------------+------------+-------+--------------+
```
---


## jetbackup_repo_rpm_url

---
```
+------------------------+------------+-------+-------------------------------------------------------------------+
| key                    | distro     | major | jetbackup_repo_rpm_url                                            |
+------------------------+------------+-------+-------------------------------------------------------------------+
| jetbackup_repo_rpm_url | AlmaLinux  | 8     | "https://repo.jetlicense.com/centOS/jetapps-repo-4096-latest.rpm" |
| jetbackup_repo_rpm_url | CentOS     | 7     | undef                                                             |
| jetbackup_repo_rpm_url | CloudLinux | 7     | undef                                                             |
| jetbackup_repo_rpm_url | CloudLinux | 8     | "https://repo.jetlicense.com/centOS/jetapps-repo-4096-latest.rpm" |
| jetbackup_repo_rpm_url | Ubuntu     | 20    | undef                                                             |
| jetbackup_repo_rpm_url | Ubuntu     | 22    | undef                                                             |
+------------------------+------------+-------+-------------------------------------------------------------------+
```
---


## leapp_can_handle_imunify

---
```
+--------------------------+------------+-------+--------------------------+
| key                      | distro     | major | leapp_can_handle_imunify |
+--------------------------+------------+-------+--------------------------+
| leapp_can_handle_imunify | AlmaLinux  | 8     | 0                        |
| leapp_can_handle_imunify | CentOS     | 7     | 0                        |
| leapp_can_handle_imunify | CloudLinux | 7     | 1                        |
| leapp_can_handle_imunify | CloudLinux | 8     | 1                        |
| leapp_can_handle_imunify | Ubuntu     | 20    | 1                        |
| leapp_can_handle_imunify | Ubuntu     | 22    | 1                        |
+--------------------------+------------+-------+--------------------------+
```
---


## leapp_can_handle_kernelcare

---
```
+-----------------------------+------------+-------+-----------------------------+
| key                         | distro     | major | leapp_can_handle_kernelcare |
+-----------------------------+------------+-------+-----------------------------+
| leapp_can_handle_kernelcare | AlmaLinux  | 8     | 0                           |
| leapp_can_handle_kernelcare | CentOS     | 7     | 0                           |
| leapp_can_handle_kernelcare | CloudLinux | 7     | 1                           |
| leapp_can_handle_kernelcare | CloudLinux | 8     | 1                           |
| leapp_can_handle_kernelcare | Ubuntu     | 20    | undef                       |
| leapp_can_handle_kernelcare | Ubuntu     | 22    | undef                       |
+-----------------------------+------------+-------+-----------------------------+
```
---


## leapp_data_pkg

---
```
+----------------+------------+-------+-------------------------+
| key            | distro     | major | leapp_data_pkg          |
+----------------+------------+-------+-------------------------+
| leapp_data_pkg | AlmaLinux  | 8     | "leapp-data-almalinux"  |
| leapp_data_pkg | CentOS     | 7     | "leapp-data-almalinux"  |
| leapp_data_pkg | CloudLinux | 7     | "leapp-data-cloudlinux" |
| leapp_data_pkg | CloudLinux | 8     | "leapp-data-cloudlinux" |
| leapp_data_pkg | Ubuntu     | 20    | undef                   |
| leapp_data_pkg | Ubuntu     | 22    | undef                   |
+----------------+------------+-------+-------------------------+
```
---


## leapp_flag

---
```
+------------+------------+-------+------------+
| key        | distro     | major | leapp_flag |
+------------+------------+-------+------------+
| leapp_flag | AlmaLinux  | 8     | undef      |
| leapp_flag | CentOS     | 7     | undef      |
| leapp_flag | CloudLinux | 7     | "--nowarn" |
| leapp_flag | CloudLinux | 8     | "--nowarn" |
| leapp_flag | Ubuntu     | 20    | undef      |
| leapp_flag | Ubuntu     | 22    | undef      |
+------------+------------+-------+------------+
```
---


## leapp_repo_beta

---
```
+-----------------+------------+-------+--------------------------------------+
| key             | distro     | major | leapp_repo_beta                      |
+-----------------+------------+-------+--------------------------------------+
| leapp_repo_beta | AlmaLinux  | 8     | ""                                   |
| leapp_repo_beta | CentOS     | 7     | ""                                   |
| leapp_repo_beta | CloudLinux | 7     | "cloudlinux-elevate-updates-testing" |
| leapp_repo_beta | CloudLinux | 8     | "cloudlinux-elevate-updates-testing" |
| leapp_repo_beta | Ubuntu     | 20    | undef                                |
| leapp_repo_beta | Ubuntu     | 22    | undef                                |
+-----------------+------------+-------+--------------------------------------+
```
---


## leapp_repo_prod

---
```
+-----------------+------------+-------+----------------------+
| key             | distro     | major | leapp_repo_prod      |
+-----------------+------------+-------+----------------------+
| leapp_repo_prod | AlmaLinux  | 8     | "elevate"            |
| leapp_repo_prod | CentOS     | 7     | "elevate"            |
| leapp_repo_prod | CloudLinux | 7     | "cloudlinux-elevate" |
| leapp_repo_prod | CloudLinux | 8     | "cloudlinux-elevate" |
| leapp_repo_prod | Ubuntu     | 20    | undef                |
| leapp_repo_prod | Ubuntu     | 22    | undef                |
+-----------------+------------+-------+----------------------+
```
---


## lts_supported

---
```
+---------------+------------+-------+---------------+
| key           | distro     | major | lts_supported |
+---------------+------------+-------+---------------+
| lts_supported | AlmaLinux  | 8     | undef         |
| lts_supported | CentOS     | 7     | 110           |
| lts_supported | CloudLinux | 7     | 110           |
| lts_supported | CloudLinux | 8     | undef         |
| lts_supported | Ubuntu     | 20    | 118           |
| lts_supported | Ubuntu     | 22    | 132           |
+---------------+------------+-------+---------------+
```
---


## name

---
```
+------+------------+-------+---------------+
| key  | distro     | major | name          |
+------+------------+-------+---------------+
| name | AlmaLinux  | 8     | "AlmaLinux8"  |
| name | CentOS     | 7     | "CentOS7"     |
| name | CloudLinux | 7     | "CloudLinux7" |
| name | CloudLinux | 8     | "CloudLinux8" |
| name | Ubuntu     | 20    | "Ubuntu20"    |
| name | Ubuntu     | 22    | "Ubuntu22"    |
+------+------------+-------+---------------+
```
---


## needs_crb

---
```
+-----------+------------+-------+-----------+
| key       | distro     | major | needs_crb |
+-----------+------------+-------+-----------+
| needs_crb | AlmaLinux  | 8     | 1         |
| needs_crb | CentOS     | 7     | 0         |
| needs_crb | CloudLinux | 7     | 0         |
| needs_crb | CloudLinux | 8     | 1         |
| needs_crb | Ubuntu     | 20    | 0         |
| needs_crb | Ubuntu     | 22    | 0         |
+-----------+------------+-------+-----------+
```
---


## needs_do_release_upgrade

---
```
+--------------------------+------------+-------+--------------------------+
| key                      | distro     | major | needs_do_release_upgrade |
+--------------------------+------------+-------+--------------------------+
| needs_do_release_upgrade | AlmaLinux  | 8     | 0                        |
| needs_do_release_upgrade | CentOS     | 7     | 0                        |
| needs_do_release_upgrade | CloudLinux | 7     | 0                        |
| needs_do_release_upgrade | CloudLinux | 8     | 0                        |
| needs_do_release_upgrade | Ubuntu     | 20    | 1                        |
| needs_do_release_upgrade | Ubuntu     | 22    | 1                        |
+--------------------------+------------+-------+--------------------------+
```
---


## needs_epel

---
```
+------------+------------+-------+------------+
| key        | distro     | major | needs_epel |
+------------+------------+-------+------------+
| needs_epel | AlmaLinux  | 8     | 1          |
| needs_epel | CentOS     | 7     | 1          |
| needs_epel | CloudLinux | 7     | 1          |
| needs_epel | CloudLinux | 8     | 1          |
| needs_epel | Ubuntu     | 20    | 0          |
| needs_epel | Ubuntu     | 22    | 0          |
+------------+------------+-------+------------+
```
---


## needs_grub_enable_blscfg

---
```
+--------------------------+------------+-------+--------------------------+
| key                      | distro     | major | needs_grub_enable_blscfg |
+--------------------------+------------+-------+--------------------------+
| needs_grub_enable_blscfg | AlmaLinux  | 8     | 1                        |
| needs_grub_enable_blscfg | CentOS     | 7     | 0                        |
| needs_grub_enable_blscfg | CloudLinux | 7     | 0                        |
| needs_grub_enable_blscfg | CloudLinux | 8     | 1                        |
| needs_grub_enable_blscfg | Ubuntu     | 20    | 0                        |
| needs_grub_enable_blscfg | Ubuntu     | 22    | 0                        |
+--------------------------+------------+-------+--------------------------+
```
---


## needs_leapp

---
```
+-------------+------------+-------+-------------+
| key         | distro     | major | needs_leapp |
+-------------+------------+-------+-------------+
| needs_leapp | AlmaLinux  | 8     | 1           |
| needs_leapp | CentOS     | 7     | 1           |
| needs_leapp | CloudLinux | 7     | 1           |
| needs_leapp | CloudLinux | 8     | 1           |
| needs_leapp | Ubuntu     | 20    | 0           |
| needs_leapp | Ubuntu     | 22    | 0           |
+-------------+------------+-------+-------------+
```
---


## needs_network_manager

---
```
+-----------------------+------------+-------+-----------------------+
| key                   | distro     | major | needs_network_manager |
+-----------------------+------------+-------+-----------------------+
| needs_network_manager | AlmaLinux  | 8     | 1                     |
| needs_network_manager | CentOS     | 7     | 0                     |
| needs_network_manager | CloudLinux | 7     | 0                     |
| needs_network_manager | CloudLinux | 8     | 1                     |
| needs_network_manager | Ubuntu     | 20    | 0                     |
| needs_network_manager | Ubuntu     | 22    | 0                     |
+-----------------------+------------+-------+-----------------------+
```
---


## needs_powertools

---
```
+------------------+------------+-------+------------------+
| key              | distro     | major | needs_powertools |
+------------------+------------+-------+------------------+
| needs_powertools | AlmaLinux  | 8     | 0                |
| needs_powertools | CentOS     | 7     | 1                |
| needs_powertools | CloudLinux | 7     | 1                |
| needs_powertools | CloudLinux | 8     | 0                |
| needs_powertools | Ubuntu     | 20    | 0                |
| needs_powertools | Ubuntu     | 22    | 0                |
+------------------+------------+-------+------------------+
```
---


## needs_sha1_enabled

---
```
+--------------------+------------+-------+--------------------+
| key                | distro     | major | needs_sha1_enabled |
+--------------------+------------+-------+--------------------+
| needs_sha1_enabled | AlmaLinux  | 8     | 1                  |
| needs_sha1_enabled | CentOS     | 7     | 0                  |
| needs_sha1_enabled | CloudLinux | 7     | 0                  |
| needs_sha1_enabled | CloudLinux | 8     | 1                  |
| needs_sha1_enabled | Ubuntu     | 20    | 0                  |
| needs_sha1_enabled | Ubuntu     | 22    | 0                  |
+--------------------+------------+-------+--------------------+
```
---


## needs_type_in_ifcfg

---
```
+---------------------+------------+-------+---------------------+
| key                 | distro     | major | needs_type_in_ifcfg |
+---------------------+------------+-------+---------------------+
| needs_type_in_ifcfg | AlmaLinux  | 8     | 1                   |
| needs_type_in_ifcfg | CentOS     | 7     | 0                   |
| needs_type_in_ifcfg | CloudLinux | 7     | 0                   |
| needs_type_in_ifcfg | CloudLinux | 8     | 1                   |
| needs_type_in_ifcfg | Ubuntu     | 20    | 0                   |
| needs_type_in_ifcfg | Ubuntu     | 22    | 0                   |
+---------------------+------------+-------+---------------------+
```
---


## needs_vdo

---
```
+-----------+------------+-------+-----------+
| key       | distro     | major | needs_vdo |
+-----------+------------+-------+-----------+
| needs_vdo | AlmaLinux  | 8     | 1         |
| needs_vdo | CentOS     | 7     | 0         |
| needs_vdo | CloudLinux | 7     | 0         |
| needs_vdo | CloudLinux | 8     | 1         |
| needs_vdo | Ubuntu     | 20    | 0         |
| needs_vdo | Ubuntu     | 22    | 0         |
+-----------+------------+-------+-----------+
```
---


## original_os_major

---
```
+-------------------+------------+-------+-------------------+
| key               | distro     | major | original_os_major |
+-------------------+------------+-------+-------------------+
| original_os_major | AlmaLinux  | 8     | 8                 |
| original_os_major | CentOS     | 7     | 7                 |
| original_os_major | CloudLinux | 7     | 7                 |
| original_os_major | CloudLinux | 8     | 8                 |
| original_os_major | Ubuntu     | 20    | 20                |
| original_os_major | Ubuntu     | 22    | 22                |
+-------------------+------------+-------+-------------------+
```
---


## package_manager

---
```
+-----------------+------------+-------+-----------------+
| key             | distro     | major | package_manager |
+-----------------+------------+-------+-----------------+
| package_manager | AlmaLinux  | 8     | "YUM"           |
| package_manager | CentOS     | 7     | "YUM"           |
| package_manager | CloudLinux | 7     | "YUM"           |
| package_manager | CloudLinux | 8     | "YUM"           |
| package_manager | Ubuntu     | 20    | "APT"           |
| package_manager | Ubuntu     | 22    | "APT"           |
+-----------------+------------+-------+-----------------+
```
---


## pkgmgr_lib_path

---
```
+-----------------+------------+-------+-----------------+
| key             | distro     | major | pkgmgr_lib_path |
+-----------------+------------+-------+-----------------+
| pkgmgr_lib_path | AlmaLinux  | 8     | "/var/lib/dnf"  |
| pkgmgr_lib_path | CentOS     | 7     | "/var/lib/yum"  |
| pkgmgr_lib_path | CloudLinux | 7     | "/var/lib/yum"  |
| pkgmgr_lib_path | CloudLinux | 8     | "/var/lib/dnf"  |
| pkgmgr_lib_path | Ubuntu     | 20    | undef           |
| pkgmgr_lib_path | Ubuntu     | 22    | undef           |
+-----------------+------------+-------+-----------------+
```
---


## pretty_name

---
```
+-------------+------------+-------+----------------+
| key         | distro     | major | pretty_name    |
+-------------+------------+-------+----------------+
| pretty_name | AlmaLinux  | 8     | "AlmaLinux 8"  |
| pretty_name | CentOS     | 7     | "CentOS 7"     |
| pretty_name | CloudLinux | 7     | "CloudLinux 7" |
| pretty_name | CloudLinux | 8     | "CloudLinux 8" |
| pretty_name | Ubuntu     | 20    | "Ubuntu 20.04" |
| pretty_name | Ubuntu     | 22    | "Ubuntu 22.04" |
+-------------+------------+-------+----------------+
```
---


## provides_mysql_governor

---
```
+-------------------------+------------+-------+-------------------------+
| key                     | distro     | major | provides_mysql_governor |
+-------------------------+------------+-------+-------------------------+
| provides_mysql_governor | AlmaLinux  | 8     | 0                       |
| provides_mysql_governor | CentOS     | 7     | 0                       |
| provides_mysql_governor | CloudLinux | 7     | 1                       |
| provides_mysql_governor | CloudLinux | 8     | 1                       |
| provides_mysql_governor | Ubuntu     | 20    | 0                       |
| provides_mysql_governor | Ubuntu     | 22    | 0                       |
+-------------------------+------------+-------+-------------------------+
```
---


## remove_els

---
```
+------------+------------+-------+------------+
| key        | distro     | major | remove_els |
+------------+------------+-------+------------+
| remove_els | AlmaLinux  | 8     | 0          |
| remove_els | CentOS     | 7     | 1          |
| remove_els | CloudLinux | 7     | 0          |
| remove_els | CloudLinux | 8     | 0          |
| remove_els | Ubuntu     | 20    | 0          |
| remove_els | Ubuntu     | 22    | 0          |
+------------+------------+-------+------------+
```
---


## set_update_tier_to_release

---
```
+----------------------------+------------+-------+----------------------------+
| key                        | distro     | major | set_update_tier_to_release |
+----------------------------+------------+-------+----------------------------+
| set_update_tier_to_release | AlmaLinux  | 8     | 0                          |
| set_update_tier_to_release | CentOS     | 7     | 1                          |
| set_update_tier_to_release | CloudLinux | 7     | 1                          |
| set_update_tier_to_release | CloudLinux | 8     | 0                          |
| set_update_tier_to_release | Ubuntu     | 20    | 0                          |
| set_update_tier_to_release | Ubuntu     | 22    | 0                          |
+----------------------------+------------+-------+----------------------------+
```
---


## should_archive_elevate_files

---
```
+------------------------------+------------+-------+------------------------------+
| key                          | distro     | major | should_archive_elevate_files |
+------------------------------+------------+-------+------------------------------+
| should_archive_elevate_files | AlmaLinux  | 8     | 1                            |
| should_archive_elevate_files | CentOS     | 7     | 0                            |
| should_archive_elevate_files | CloudLinux | 7     | 0                            |
| should_archive_elevate_files | CloudLinux | 8     | 1                            |
| should_archive_elevate_files | Ubuntu     | 20    | 0                            |
| should_archive_elevate_files | Ubuntu     | 22    | 1                            |
+------------------------------+------------+-------+------------------------------+
```
---


## should_check_cloudlinux_license

---
```
+---------------------------------+------------+-------+---------------------------------+
| key                             | distro     | major | should_check_cloudlinux_license |
+---------------------------------+------------+-------+---------------------------------+
| should_check_cloudlinux_license | AlmaLinux  | 8     | 0                               |
| should_check_cloudlinux_license | CentOS     | 7     | 0                               |
| should_check_cloudlinux_license | CloudLinux | 7     | 1                               |
| should_check_cloudlinux_license | CloudLinux | 8     | 1                               |
| should_check_cloudlinux_license | Ubuntu     | 20    | 0                               |
| should_check_cloudlinux_license | Ubuntu     | 22    | 0                               |
+---------------------------------+------------+-------+---------------------------------+
```
---


## skip_minor_version_check

---
```
+--------------------------+------------+-------+--------------------------+
| key                      | distro     | major | skip_minor_version_check |
+--------------------------+------------+-------+--------------------------+
| skip_minor_version_check | AlmaLinux  | 8     | 1                        |
| skip_minor_version_check | CentOS     | 7     | 0                        |
| skip_minor_version_check | CloudLinux | 7     | 0                        |
| skip_minor_version_check | CloudLinux | 8     | 1                        |
| skip_minor_version_check | Ubuntu     | 20    | 1                        |
| skip_minor_version_check | Ubuntu     | 22    | 1                        |
+--------------------------+------------+-------+--------------------------+
```
---


## supported_cpanel_mysql_versions

---
```
+---------------------------------+------------+-------+----------------------------------------------+
| key                             | distro     | major | supported_cpanel_mysql_versions              |
+---------------------------------+------------+-------+----------------------------------------------+
| supported_cpanel_mysql_versions | AlmaLinux  | 8     | [10.11, 10.5, 10.6, 11.4, "8.0", 8.4]        |
| supported_cpanel_mysql_versions | CentOS     | 7     | [10.11, 10.3, 10.4, 10.5, 10.6, 11.4, "8.0"] |
| supported_cpanel_mysql_versions | CloudLinux | 7     | [10.11, 10.3, 10.4, 10.5, 10.6, 11.4, "8.0"] |
| supported_cpanel_mysql_versions | CloudLinux | 8     | [10.11, 10.5, 10.6, 11.4, "8.0", 8.4]        |
| supported_cpanel_mysql_versions | Ubuntu     | 20    | [10.11, 10.6, "8.0"]                         |
| supported_cpanel_mysql_versions | Ubuntu     | 22    | [10.11, 11.4, "8.0", 8.4]                    |
+---------------------------------+------------+-------+----------------------------------------------+
```
---


## supported_cpanel_nameserver_types

---
```
+-----------------------------------+------------+-------+-----------------------------------+
| key                               | distro     | major | supported_cpanel_nameserver_types |
+-----------------------------------+------------+-------+-----------------------------------+
| supported_cpanel_nameserver_types | AlmaLinux  | 8     | ["bind", "disabled", "powerdns"]  |
| supported_cpanel_nameserver_types | CentOS     | 7     | ["bind", "disabled", "powerdns"]  |
| supported_cpanel_nameserver_types | CloudLinux | 7     | ["bind", "disabled", "powerdns"]  |
| supported_cpanel_nameserver_types | CloudLinux | 8     | ["bind", "disabled", "powerdns"]  |
| supported_cpanel_nameserver_types | Ubuntu     | 20    | ["disabled", "powerdns"]          |
| supported_cpanel_nameserver_types | Ubuntu     | 22    | ["disabled", "powerdns"]          |
+-----------------------------------+------------+-------+-----------------------------------+
```
---


## supports_jetbackup

---
```
+--------------------+------------+-------+--------------------+
| key                | distro     | major | supports_jetbackup |
+--------------------+------------+-------+--------------------+
| supports_jetbackup | AlmaLinux  | 8     | 1                  |
| supports_jetbackup | CentOS     | 7     | 1                  |
| supports_jetbackup | CloudLinux | 7     | 1                  |
| supports_jetbackup | CloudLinux | 8     | 1                  |
| supports_jetbackup | Ubuntu     | 20    | 1                  |
| supports_jetbackup | Ubuntu     | 22    | 1                  |
+--------------------+------------+-------+--------------------+
```
---


## supports_kernelcare

---
```
+---------------------+------------+-------+---------------------+
| key                 | distro     | major | supports_kernelcare |
+---------------------+------------+-------+---------------------+
| supports_kernelcare | AlmaLinux  | 8     | 1                   |
| supports_kernelcare | CentOS     | 7     | 1                   |
| supports_kernelcare | CloudLinux | 7     | 1                   |
| supports_kernelcare | CloudLinux | 8     | 1                   |
| supports_kernelcare | Ubuntu     | 20    | 0                   |
| supports_kernelcare | Ubuntu     | 22    | 0                   |
+---------------------+------------+-------+---------------------+
```
---


## supports_named_tiers

---
```
+----------------------+------------+-------+----------------------+
| key                  | distro     | major | supports_named_tiers |
+----------------------+------------+-------+----------------------+
| supports_named_tiers | AlmaLinux  | 8     | 1                    |
| supports_named_tiers | CentOS     | 7     | 0                    |
| supports_named_tiers | CloudLinux | 7     | 0                    |
| supports_named_tiers | CloudLinux | 8     | 1                    |
| supports_named_tiers | Ubuntu     | 20    | 0                    |
| supports_named_tiers | Ubuntu     | 22    | 0                    |
+----------------------+------------+-------+----------------------+
```
---


## supports_postgresql

---
```
+---------------------+------------+-------+---------------------+
| key                 | distro     | major | supports_postgresql |
+---------------------+------------+-------+---------------------+
| supports_postgresql | AlmaLinux  | 8     | 1                   |
| supports_postgresql | CentOS     | 7     | 1                   |
| supports_postgresql | CloudLinux | 7     | 1                   |
| supports_postgresql | CloudLinux | 8     | 1                   |
| supports_postgresql | Ubuntu     | 20    | 0                   |
| supports_postgresql | Ubuntu     | 22    | 0                   |
+---------------------+------------+-------+---------------------+
```
---


## upgrade_to_pretty_name

---
```
+------------------------+------------+-------+------------------------+
| key                    | distro     | major | upgrade_to_pretty_name |
+------------------------+------------+-------+------------------------+
| upgrade_to_pretty_name | AlmaLinux  | 8     | "AlmaLinux 9"          |
| upgrade_to_pretty_name | CentOS     | 7     | "AlmaLinux 8"          |
| upgrade_to_pretty_name | CloudLinux | 7     | "CloudLinux 8"         |
| upgrade_to_pretty_name | CloudLinux | 8     | "CloudLinux 9"         |
| upgrade_to_pretty_name | Ubuntu     | 20    | "Ubuntu 22.04"         |
| upgrade_to_pretty_name | Ubuntu     | 22    | "Ubuntu 24.04"         |
+------------------------+------------+-------+------------------------+
```
---


## vetted_apt_lists

---
```
+------------------+------------+-------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| key              | distro     | major | vetted_apt_lists                                                                                                                                                                                                                                             |
+------------------+------------+-------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| vetted_apt_lists | AlmaLinux  | 8     | {}                                                                                                                                                                                                                                                           |
| vetted_apt_lists | CentOS     | 7     | {}                                                                                                                                                                                                                                                           |
| vetted_apt_lists | CloudLinux | 7     | {}                                                                                                                                                                                                                                                           |
| vetted_apt_lists | CloudLinux | 8     | {}                                                                                                                                                                                                                                                           |
|                  |            |       |                                                                                                                                                                                                                                                              |
| vetted_apt_lists | Ubuntu     | 20    | {\n                                                                                                                                                                                                                                                          |
|                  |            |       |   "alt-common-els.list"    => "deb [arch=amd64] https://repo.alt.tuxcare.com/alt-common/deb/ubuntu/22.04/stable jammy main",\n                                                                                                                               |
|                  |            |       |   "cpanel-plugins.list"    => "deb mirror://httpupdate.cpanel.net/cpanel-plugins-u22-mirrorlist ./",\n                                                                                                                                                       |
|                  |            |       |   "droplet-agent.list"     => "deb [signed-by=/usr/share/keyrings/droplet-agent-keyring.gpg] https://repos-droplet.digitalocean.com/apt/droplet-agent main main",\n                                                                                          |
|                  |            |       |   "EA4.list"               => "deb mirror://httpupdate.cpanel.net/ea4-u22-mirrorlist ./",\n                                                                                                                                                                  |
|                  |            |       |   "imunify-rollout.list"   => "deb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-1/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-2/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/2 |
|                  |            |       | 2.04/slot-3/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-4/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-5/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/s |
|                  |            |       | lot-6/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-7/ jammy main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/22.04/slot-8/ jammy main",\n                                                                    |
|                  |            |       |   "imunify360.list"        => "deb [arch=amd64] https://repo.imunify360.cloudlinux.com/imunify360/ubuntu/22.04/ jammy main",\n                                                                                                                               |
|                  |            |       |   "jetapps-alpha.list"     => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/alpha main",\n                                                                                                                                                      |
|                  |            |       |   "jetapps-base.list"      => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/base main",\n                                                                                                                                                       |
|                  |            |       |   "jetapps-beta.list"      => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/beta main",\n                                                                                                                                                       |
|                  |            |       |   "jetapps-edge.list"      => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/edge main",\n                                                                                                                                                       |
|                  |            |       |   "jetapps-plugins.list"   => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/plugins main",\n                                                                                                                                                    |
|                  |            |       |   "jetapps-rc.list"        => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/rc main",\n                                                                                                                                                         |
|                  |            |       |   "jetapps-release.list"   => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/release main",\n                                                                                                                                                    |
|                  |            |       |   "jetapps-stable.list"    => "deb [arch=amd64] https://repo.jetlicense.com/ubuntu jammy/stable main",\n                                                                                                                                                     |
|                  |            |       |   "mysql.list"             => "# Use command 'dpkg-reconfigure mysql-apt-config' as root for modifications.\ndeb https://repo.mysql.com/apt/ubuntu/ jammy mysql-apt-config\ndeb https://repo.mysql.com/apt/ubuntu/ jammy mysql-8.0\ndeb https://repo.mysql.c |
|                  |            |       | om/apt/ubuntu/ jammy mysql-tools\n#deb https://repo.mysql.com/apt/ubuntu/ jammy mysql-tools-preview\ndeb-src https://repo.mysql.com/apt/ubuntu/ jammy mysql-8.0",\n                                                                                          |
|                  |            |       |   "wp-toolkit-cpanel.list" => "# WP Toolkit\ndeb [signed-by=/etc/apt/keyrings/wp-toolkit-cpanel.gpg] https://wp-toolkit.plesk.com/cPanel/Ubuntu-22.04-x86_64/latest/wp-toolkit/ ./\n\n# WP Toolkit Thirdparties\ndeb [signed-by=/etc/apt/keyrings/wp-toolkit |
|                  |            |       | -cpanel.gpg] https://wp-toolkit.plesk.com/cPanel/Ubuntu-22.04-x86_64/latest/thirdparty/ ./",\n                                                                                                                                                               |
|                  |            |       | }                                                                                                                                                                                                                                                            |
|                  |            |       |                                                                                                                                                                                                                                                              |
| vetted_apt_lists | Ubuntu     | 22    | {\n                                                                                                                                                                                                                                                          |
|                  |            |       |   "alt-common-els.list"    => "deb [arch=amd64] https://repo.alt.tuxcare.com/alt-common/deb/ubuntu/24.04/stable noble main",\n                                                                                                                               |
|                  |            |       |   "cpanel-plugins.list"    => "deb mirror://httpupdate.cpanel.net/cpanel-plugins-u24-mirrorlist ./",\n                                                                                                                                                       |
|                  |            |       |   "droplet-agent.list"     => "deb [signed-by=/usr/share/keyrings/droplet-agent-keyring.gpg] https://repos-droplet.digitalocean.com/apt/droplet-agent main main",\n                                                                                          |
|                  |            |       |   "EA4.list"               => "deb mirror://httpupdate.cpanel.net/ea4-u24-mirrorlist ./",\n                                                                                                                                                                  |
|                  |            |       |   "imunify-rollout.list"   => "deb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-1/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-2/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/2 |
|                  |            |       | 4.04/slot-3/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-4/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-5/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/s |
|                  |            |       | lot-6/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-7/ noble main\ndeb [arch=amd64] https://download.imunify360.com/ubuntu/24.04/slot-8/ noble main",\n                                                                    |
|                  |            |       |   "imunify360.list"        => "deb [arch=amd64] https://repo.imunify360.cloudlinux.com/imunify360/ubuntu/24.04/ noble main",\n                                                                                                                               |
|                  |            |       |   "jetapps-alpha.list"     => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/alpha main",\n                                                                                            |
|                  |            |       |   "jetapps-base.list"      => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/base main",\n                                                                                             |
|                  |            |       |   "jetapps-beta.list"      => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/beta main",\n                                                                                             |
|                  |            |       |   "jetapps-edge.list"      => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/edge main",\n                                                                                             |
|                  |            |       |   "jetapps-plugins.list"   => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/plugins main",\n                                                                                          |
|                  |            |       |   "jetapps-rc.list"        => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/rc main",\n                                                                                               |
|                  |            |       |   "jetapps-release.list"   => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/release main",\n                                                                                          |
|                  |            |       |   "jetapps-stable.list"    => "deb [signed-by=/usr/share/keyrings/jetapps-archive-keyring.gpg arch=amd64] https://repo.jetlicense.com/ubuntu noble/stable main",\n                                                                                           |
|                  |            |       |   "mariadb.list"           => "deb [arch=amd64,arm64] https://dlm.mariadb.com/repo/mariadb-server/10.11/repo/ubuntu noble main\ndeb [arch=amd64,arm64] https://dlm.mariadb.com/repo/mariadb-server/10.11/repo/ubuntu noble main/debug",\n                    |
|                  |            |       |   "wp-toolkit-cpanel.list" => "# WP Toolkit\ndeb [signed-by=/etc/apt/keyrings/wp-toolkit-cpanel.gpg] https://wp-toolkit.plesk.com/cPanel/Ubuntu-24.04-x86_64/latest/wp-toolkit/ ./\n\n# WP Toolkit Thirdparties\ndeb [signed-by=/etc/apt/keyrings/wp-toolkit |
|                  |            |       | -cpanel.gpg] https://wp-toolkit.plesk.com/cPanel/Ubuntu-24.04-x86_64/latest/thirdparty/ ./",\n                                                                                                                                                               |
|                  |            |       | }                                                                                                                                                                                                                                                            |
+------------------+------------+-------+--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
```
---


## vetted_mysql_yum_repo_ids

---
```
+---------------------------+------------+-------+------------------------------------------------------------------------------+
| key                       | distro     | major | vetted_mysql_yum_repo_ids                                                    |
+---------------------------+------------+-------+------------------------------------------------------------------------------+
| vetted_mysql_yum_repo_ids | AlmaLinux  | 8     | [\n                                                                          |
|                           |            |       |   qr/(?^u:^mysql-(?:tools|cluster)-[0-9]\.[0-9]-lts-community$)/,\n          |
|                           |            |       |   qr/(?^u:^mysql-[0-9]\.[0-9]-lts-community$)/,\n                            |
|                           |            |       | ]                                                                            |
|                           |            |       |                                                                              |
| vetted_mysql_yum_repo_ids | CentOS     | 7     | [\n                                                                          |
|                           |            |       |   qr/(?^u:^MariaDB[0-9]+$)/,\n                                               |
|                           |            |       |   qr/(?^u:^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$)/,\n |
|                           |            |       |   qr/(?^u:^mysql-connectors-community(?:-(?:source|debuginfo))?$)/,\n        |
|                           |            |       |   qr/(?^u:^mysql-tools-community(?:-(?:source|debuginfo))?$)/,\n             |
|                           |            |       |   qr/(?^u:^mysql-tools-preview(?:-source)?$)/,\n                             |
|                           |            |       |   qr/(?^u:^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$)/,\n           |
|                           |            |       | ]                                                                            |
|                           |            |       |                                                                              |
| vetted_mysql_yum_repo_ids | CloudLinux | 7     | [\n                                                                          |
|                           |            |       |   qr/(?^u:^MariaDB[0-9]+$)/,\n                                               |
|                           |            |       |   qr/(?^u:^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$)/,\n |
|                           |            |       |   qr/(?^u:^mysql-connectors-community(?:-(?:source|debuginfo))?$)/,\n        |
|                           |            |       |   qr/(?^u:^mysql-tools-community(?:-(?:source|debuginfo))?$)/,\n             |
|                           |            |       |   qr/(?^u:^mysql-tools-preview(?:-source)?$)/,\n                             |
|                           |            |       |   qr/(?^u:^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$)/,\n           |
|                           |            |       | ]                                                                            |
|                           |            |       |                                                                              |
| vetted_mysql_yum_repo_ids | CloudLinux | 8     | [\n                                                                          |
|                           |            |       |   qr/(?^u:^mysql-(?:tools|cluster)-[0-9]\.[0-9]-lts-community$)/,\n          |
|                           |            |       |   qr/(?^u:^mysql-[0-9]\.[0-9]-lts-community$)/,\n                            |
|                           |            |       | ]                                                                            |
|                           |            |       |                                                                              |
| vetted_mysql_yum_repo_ids | Ubuntu     | 20    | undef                                                                        |
| vetted_mysql_yum_repo_ids | Ubuntu     | 22    | undef                                                                        |
+---------------------------+------------+-------+------------------------------------------------------------------------------+
```
---


## vetted_yum_repo

---
```
+-----------------+------------+-------+------------------------------------------------------------------------------------+
| key             | distro     | major | vetted_yum_repo                                                                    |
+-----------------+------------+-------+------------------------------------------------------------------------------------+
| vetted_yum_repo | AlmaLinux  | 8     | [\n                                                                                |
|                 |            |       |   qr/(?^u:^EA4(?:-c\$releasever)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^MariaDB[0-9]+$)/,\n                                                     |
|                 |            |       |   qr/(?^u:^centos-kernel(?:-experimental)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^elasticsearch(?:7\.x)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^elevate(?:-source)?$)/,\n                                               |
|                 |            |       |   qr/(?^u:^epel(?:-testing)?$)/,\n                                                 |
|                 |            |       |   qr/(?^u:^fortimonitor(?:\.repo)?$)/,\n                                           |
|                 |            |       |   qr/(?^u:^imunify360-rollout-[0-9]+$)/,\n                                         |
|                 |            |       |   qr/(?^u:^jetapps-(?:stable|beta|edge)$)/,\n                                      |
|                 |            |       |   qr/(?^u:^mysql-(?:tools|cluster)-[0-9]\.[0-9]-lts-community$)/,\n                |
|                 |            |       |   qr/(?^u:^mysql-[0-9]\.[0-9]-lts-community$)/,\n                                  |
|                 |            |       |   qr/(?^u:^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$)/,\n       |
|                 |            |       |   qr/(?^u:^mysql-connectors-community(?:-(?:source|debuginfo))?$)/,\n              |
|                 |            |       |   qr/(?^u:^mysql-tools-community(?:-(?:source|debuginfo))?$)/,\n                   |
|                 |            |       |   qr/(?^u:^mysql-tools-preview(?:-source)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$)/,\n                 |
|                 |            |       |   qr/(?^u:^panopta(?:\.repo)?$)/,\n                                                |
|                 |            |       |   qr/(?^u:^ul($|_))/,\n                                                            |
|                 |            |       |   qr/(?^u:^wp-toolkit-(?:cpanel|thirdparties)$)/,\n                                |
|                 |            |       |   "alt-common",\n                                                                  |
|                 |            |       |   "appstream",\n                                                                   |
|                 |            |       |   "base",\n                                                                        |
|                 |            |       |   "c7-media",\n                                                                    |
|                 |            |       |   "centosplus",\n                                                                  |
|                 |            |       |   "cp-dev-tools",\n                                                                |
|                 |            |       |   "cpanel-addons-production-feed",\n                                               |
|                 |            |       |   "cpanel-plugins",\n                                                              |
|                 |            |       |   "cr",\n                                                                          |
|                 |            |       |   "ct-preset",\n                                                                   |
|                 |            |       |   "digitalocean-agent",\n                                                          |
|                 |            |       |   "droplet-agent",\n                                                               |
|                 |            |       |   "extras",\n                                                                      |
|                 |            |       |   "fasttrack",\n                                                                   |
|                 |            |       |   "hgdedi",\n                                                                      |
|                 |            |       |   "imunify360",\n                                                                  |
|                 |            |       |   "imunify360-ea-php-hardened",\n                                                  |
|                 |            |       |   "influxdata",\n                                                                  |
|                 |            |       |   "influxdb",\n                                                                    |
|                 |            |       |   "jetapps",\n                                                                     |
|                 |            |       |   "kernelcare",\n                                                                  |
|                 |            |       |   "platform360-cpanel",\n                                                          |
|                 |            |       |   "powertools",\n                                                                  |
|                 |            |       |   "r1soft",\n                                                                      |
|                 |            |       |   "updates",\n                                                                     |
|                 |            |       | ]                                                                                  |
|                 |            |       |                                                                                    |
| vetted_yum_repo | CentOS     | 7     | [\n                                                                                |
|                 |            |       |   qr/(?^u:^EA4(?:-c\$releasever)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^MariaDB[0-9]+$)/,\n                                                     |
|                 |            |       |   qr/(?^u:^centos-kernel(?:-experimental)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^elasticsearch(?:7\.x)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^elevate(?:-source)?$)/,\n                                               |
|                 |            |       |   qr/(?^u:^epel(?:-testing)?$)/,\n                                                 |
|                 |            |       |   qr/(?^u:^fortimonitor(?:\.repo)?$)/,\n                                           |
|                 |            |       |   qr/(?^u:^imunify360-rollout-[0-9]+$)/,\n                                         |
|                 |            |       |   qr/(?^u:^jetapps-(?:stable|beta|edge)$)/,\n                                      |
|                 |            |       |   qr/(?^u:^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$)/,\n       |
|                 |            |       |   qr/(?^u:^mysql-connectors-community(?:-(?:source|debuginfo))?$)/,\n              |
|                 |            |       |   qr/(?^u:^mysql-tools-community(?:-(?:source|debuginfo))?$)/,\n                   |
|                 |            |       |   qr/(?^u:^mysql-tools-preview(?:-source)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$)/,\n                 |
|                 |            |       |   qr/(?^u:^panopta(?:\.repo)?$)/,\n                                                |
|                 |            |       |   qr/(?^u:^ul($|_))/,\n                                                            |
|                 |            |       |   qr/(?^u:^wp-toolkit-(?:cpanel|thirdparties)$)/,\n                                |
|                 |            |       |   qr/(?^u:centos7[-]*els(-rollout-[0-9]+|))/,\n                                    |
|                 |            |       |   "alt-common",\n                                                                  |
|                 |            |       |   "base",\n                                                                        |
|                 |            |       |   "c7-media",\n                                                                    |
|                 |            |       |   "centosplus",\n                                                                  |
|                 |            |       |   "cp-dev-tools",\n                                                                |
|                 |            |       |   "cpanel-addons-production-feed",\n                                               |
|                 |            |       |   "cpanel-plugins",\n                                                              |
|                 |            |       |   "cr",\n                                                                          |
|                 |            |       |   "ct-preset",\n                                                                   |
|                 |            |       |   "digitalocean-agent",\n                                                          |
|                 |            |       |   "droplet-agent",\n                                                               |
|                 |            |       |   "extras",\n                                                                      |
|                 |            |       |   "fasttrack",\n                                                                   |
|                 |            |       |   "hgdedi",\n                                                                      |
|                 |            |       |   "imunify360",\n                                                                  |
|                 |            |       |   "imunify360-ea-php-hardened",\n                                                  |
|                 |            |       |   "influxdata",\n                                                                  |
|                 |            |       |   "influxdb",\n                                                                    |
|                 |            |       |   "jetapps",\n                                                                     |
|                 |            |       |   "kernelcare",\n                                                                  |
|                 |            |       |   "platform360-cpanel",\n                                                          |
|                 |            |       |   "r1soft",\n                                                                      |
|                 |            |       |   "updates",\n                                                                     |
|                 |            |       | ]                                                                                  |
|                 |            |       |                                                                                    |
| vetted_yum_repo | CloudLinux | 7     | [\n                                                                                |
|                 |            |       |   qr/(?^u:^EA4(?:-c\$releasever)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^MariaDB[0-9]+$)/,\n                                                     |
|                 |            |       |   qr/(?^u:^centos-kernel(?:-experimental)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^cl-mysql(?:-meta)?)/,\n                                                 |
|                 |            |       |   qr/(?^u:^cloudlinux(?:-(?:base|updates|extras|compat|imunify360|elevate))?$)/,\n |
|                 |            |       |   qr/(?^u:^cloudlinux-ea4(?:-[0-9]+)?$)/,\n                                        |
|                 |            |       |   qr/(?^u:^cloudlinux-ea4-rollout(?:-[0-9]+)?$)/,\n                                |
|                 |            |       |   qr/(?^u:^cloudlinux-rollout(?:-[0-9]+)?$)/,\n                                    |
|                 |            |       |   qr/(?^u:^elasticsearch(?:7\.x)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^elevate(?:-source)?$)/,\n                                               |
|                 |            |       |   qr/(?^u:^epel(?:-testing)?$)/,\n                                                 |
|                 |            |       |   qr/(?^u:^fortimonitor(?:\.repo)?$)/,\n                                           |
|                 |            |       |   qr/(?^u:^imunify360-rollout-[0-9]+$)/,\n                                         |
|                 |            |       |   qr/(?^u:^jetapps-(?:stable|beta|edge)$)/,\n                                      |
|                 |            |       |   qr/(?^u:^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$)/,\n       |
|                 |            |       |   qr/(?^u:^mysql-connectors-community(?:-(?:source|debuginfo))?$)/,\n              |
|                 |            |       |   qr/(?^u:^mysql-tools-community(?:-(?:source|debuginfo))?$)/,\n                   |
|                 |            |       |   qr/(?^u:^mysql-tools-preview(?:-source)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$)/,\n                 |
|                 |            |       |   qr/(?^u:^panopta(?:\.repo)?$)/,\n                                                |
|                 |            |       |   qr/(?^u:^repo\.cloudlinux\.com_)/,\n                                             |
|                 |            |       |   qr/(?^u:^ul($|_))/,\n                                                            |
|                 |            |       |   qr/(?^u:^wp-toolkit-(?:cpanel|thirdparties)$)/,\n                                |
|                 |            |       |   "alt-common",\n                                                                  |
|                 |            |       |   "base",\n                                                                        |
|                 |            |       |   "c7-media",\n                                                                    |
|                 |            |       |   "centosplus",\n                                                                  |
|                 |            |       |   "cl-ea4",\n                                                                      |
|                 |            |       |   "cl7h",\n                                                                        |
|                 |            |       |   "cp-dev-tools",\n                                                                |
|                 |            |       |   "cpanel-addons-production-feed",\n                                               |
|                 |            |       |   "cpanel-plugins",\n                                                              |
|                 |            |       |   "cr",\n                                                                          |
|                 |            |       |   "ct-preset",\n                                                                   |
|                 |            |       |   "digitalocean-agent",\n                                                          |
|                 |            |       |   "droplet-agent",\n                                                               |
|                 |            |       |   "extras",\n                                                                      |
|                 |            |       |   "fasttrack",\n                                                                   |
|                 |            |       |   "hgdedi",\n                                                                      |
|                 |            |       |   "imunify360",\n                                                                  |
|                 |            |       |   "imunify360-ea-php-hardened",\n                                                  |
|                 |            |       |   "influxdata",\n                                                                  |
|                 |            |       |   "influxdb",\n                                                                    |
|                 |            |       |   "jetapps",\n                                                                     |
|                 |            |       |   "kernelcare",\n                                                                  |
|                 |            |       |   "mysqclient",\n                                                                  |
|                 |            |       |   "mysql-debuginfo",\n                                                             |
|                 |            |       |   "platform360-cpanel",\n                                                          |
|                 |            |       |   "r1soft",\n                                                                      |
|                 |            |       |   "updates",\n                                                                     |
|                 |            |       | ]                                                                                  |
|                 |            |       |                                                                                    |
| vetted_yum_repo | CloudLinux | 8     | [\n                                                                                |
|                 |            |       |   qr/(?^u:^EA4(?:-c\$releasever)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^MariaDB[0-9]+$)/,\n                                                     |
|                 |            |       |   qr/(?^u:^centos-kernel(?:-experimental)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^cl-mysql(?:-meta)?)/,\n                                                 |
|                 |            |       |   qr/(?^u:^cloudlinux(?:-(?:base|updates|extras|compat|imunify360|elevate))?$)/,\n |
|                 |            |       |   qr/(?^u:^cloudlinux-ea4(?:-[0-9]+)?$)/,\n                                        |
|                 |            |       |   qr/(?^u:^cloudlinux-ea4-rollout(?:-[0-9]+)?$)/,\n                                |
|                 |            |       |   qr/(?^u:^cloudlinux-rollout(?:-[0-9]+)?$)/,\n                                    |
|                 |            |       |   qr/(?^u:^elasticsearch(?:7\.x)?$)/,\n                                            |
|                 |            |       |   qr/(?^u:^elevate(?:-source)?$)/,\n                                               |
|                 |            |       |   qr/(?^u:^epel(?:-testing)?$)/,\n                                                 |
|                 |            |       |   qr/(?^u:^fortimonitor(?:\.repo)?$)/,\n                                           |
|                 |            |       |   qr/(?^u:^imunify360-rollout-[0-9]+$)/,\n                                         |
|                 |            |       |   qr/(?^u:^jetapps-(?:stable|beta|edge)$)/,\n                                      |
|                 |            |       |   qr/(?^u:^mysql-(?:tools|cluster)-[0-9]\.[0-9]-lts-community$)/,\n                |
|                 |            |       |   qr/(?^u:^mysql-[0-9]\.[0-9]-lts-community$)/,\n                                  |
|                 |            |       |   qr/(?^u:^mysql-cluster-[0-9.]{3}-community(?:-(?:source|debuginfo))?$)/,\n       |
|                 |            |       |   qr/(?^u:^mysql-connectors-community(?:-(?:source|debuginfo))?$)/,\n              |
|                 |            |       |   qr/(?^u:^mysql-tools-community(?:-(?:source|debuginfo))?$)/,\n                   |
|                 |            |       |   qr/(?^u:^mysql-tools-preview(?:-source)?$)/,\n                                   |
|                 |            |       |   qr/(?^u:^mysql[0-9]{2}-community(?:-(?:source|debuginfo))?$)/,\n                 |
|                 |            |       |   qr/(?^u:^panopta(?:\.repo)?$)/,\n                                                |
|                 |            |       |   qr/(?^u:^repo\.cloudlinux\.com_)/,\n                                             |
|                 |            |       |   qr/(?^u:^ul($|_))/,\n                                                            |
|                 |            |       |   qr/(?^u:^wp-toolkit-(?:cpanel|thirdparties)$)/,\n                                |
|                 |            |       |   "alt-common",\n                                                                  |
|                 |            |       |   "appstream",\n                                                                   |
|                 |            |       |   "base",\n                                                                        |
|                 |            |       |   "c7-media",\n                                                                    |
|                 |            |       |   "centosplus",\n                                                                  |
|                 |            |       |   "cl-ea4",\n                                                                      |
|                 |            |       |   "cl7h",\n                                                                        |
|                 |            |       |   "cp-dev-tools",\n                                                                |
|                 |            |       |   "cpanel-addons-production-feed",\n                                               |
|                 |            |       |   "cpanel-plugins",\n                                                              |
|                 |            |       |   "cr",\n                                                                          |
|                 |            |       |   "ct-preset",\n                                                                   |
|                 |            |       |   "digitalocean-agent",\n                                                          |
|                 |            |       |   "droplet-agent",\n                                                               |
|                 |            |       |   "extras",\n                                                                      |
|                 |            |       |   "fasttrack",\n                                                                   |
|                 |            |       |   "hgdedi",\n                                                                      |
|                 |            |       |   "imunify360",\n                                                                  |
|                 |            |       |   "imunify360-ea-php-hardened",\n                                                  |
|                 |            |       |   "influxdata",\n                                                                  |
|                 |            |       |   "influxdb",\n                                                                    |
|                 |            |       |   "jetapps",\n                                                                     |
|                 |            |       |   "kernelcare",\n                                                                  |
|                 |            |       |   "mysqclient",\n                                                                  |
|                 |            |       |   "mysql-debuginfo",\n                                                             |
|                 |            |       |   "platform360-cpanel",\n                                                          |
|                 |            |       |   "powertools",\n                                                                  |
|                 |            |       |   "r1soft",\n                                                                      |
|                 |            |       |   "updates",\n                                                                     |
|                 |            |       | ]                                                                                  |
|                 |            |       |                                                                                    |
| vetted_yum_repo | Ubuntu     | 20    | undef                                                                              |
| vetted_yum_repo | Ubuntu     | 22    | undef                                                                              |
+-----------------+------------+-------+------------------------------------------------------------------------------------+
```
---


## yum_conf_needs_plugins

---
```
+------------------------+------------+-------+------------------------+
| key                    | distro     | major | yum_conf_needs_plugins |
+------------------------+------------+-------+------------------------+
| yum_conf_needs_plugins | AlmaLinux  | 8     | 0                      |
| yum_conf_needs_plugins | CentOS     | 7     | 0                      |
| yum_conf_needs_plugins | CloudLinux | 7     | 1                      |
| yum_conf_needs_plugins | CloudLinux | 8     | 0                      |
| yum_conf_needs_plugins | Ubuntu     | 20    | 0                      |
| yum_conf_needs_plugins | Ubuntu     | 22    | 0                      |
+------------------------+------------+-------+------------------------+
```
---

