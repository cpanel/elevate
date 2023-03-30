#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use constant MINIMUM_LTS_SUPPORTED => 102;

require $FindBin::Bin . '/../elevate-cpanel';

my $logger_mock = Test::MockModule->new('Elevate::Logger');
$logger_mock->redefine( init => sub { die "should not call init_logger" } );

my $cpev_mock = Test::MockModule->new('cpev');
$cpev_mock->redefine( _check_yum_repos => 0 );

my $script_mock = Test::MockModule->new('Elevate::Script');
$script_mock->redefine( '_build_latest_version' => cpev::VERSION );

my $cpev = cpev->new( _abort_on_first_blocker => 1 );

{
    note "cPanel & WHM missing blocker";

    my $mock_cpanel = Test::MockFile->file('/usr/local/cpanel/cpanel');

    is(
        dies { $cpev->_blocker_is_missing_cpanel_whm() },
        {
            id  => 1,
            msg => 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.',
        },
        "/ULC/cpanel is missing."
    );

    $mock_cpanel->touch;

    is(
        dies { $cpev->_blocker_is_missing_cpanel_whm() },
        {
            id  => 1,
            msg => 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.',
        },
        "/ULC/cpanel is not -x"
    );

    $mock_cpanel->chmod(0755);
    is( $cpev->_blocker_is_missing_cpanel_whm(), 0, "/ULC/cpanel is now present and -x" );

}

{
    note "cPanel & WHM not fully populated.";

    no warnings 'once';
    local $Cpanel::Version::Tiny::major_version;
    is(
        dies { $cpev->_blocker_is_invalid_cpanel_whm() },
        {
            id  => 1,
            msg => 'Invalid cPanel & WHM major_version.',
        },
        q{no major_version means we're not cPanel?}
    );

    $Cpanel::Version::Tiny::major_version = 106;
    is( $cpev->_blocker_is_invalid_cpanel_whm(), 0, '11.106 is unsupported for this script.' );
}

{
    note "cPanel & WHM minimum LTS.";

    local $Cpanel::Version::Tiny::major_version = 100;
    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.109.0.9999';

    is(
        dies { $cpev->_blocker_is_newer_than_lts() },
        {
            id  => 2,
            msg => 'This version 11.109.0.9999 does not support upgrades to AlmaLinux 8. Please upgrade to cPanel version 102 or better.',
        },
        q{cPanel version must be above the known LTS.}
    );

    $Cpanel::Version::Tiny::major_version = MINIMUM_LTS_SUPPORTED;
    is( $cpev->_blocker_is_newer_than_lts(), 0, 'Recent LTS version passes this test.' );

}

{
    note "cPanel & WHM latest version.";

    my $mock_tiers = Test::MockModule->new('Cpanel::Update::Tiers');
    $mock_tiers->redefine(
        sync_tiers_file => 1,
        tiers_hash      => {

            flags => { "is_main" => 1 },
            tiers => {
                "11.100" => [
                    {
                        "build"   => "11.100.0.11",
                        "is_main" => 1,
                        "named"   => [ "release", "stable" ],
                    }
                ],
                "11.102" => [
                    {
                        "build"   => "11.102.0.7",
                        "is_main" => 1,
                        "named"   => [ "current", "edge" ],
                    }
                ],
            },
        },
    );

    $cpev->{'_getopt'}{'skip-cpanel-version-check'} = 1;
    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    is( $cpev->_blocker_cpanel_needs_update(), 0, "blockers_check() passes with skip-cpanel-version-check specified." );
    message_seen( 'WARN', qr{The --skip-cpanel-version-check option was specified! This option is provided for testing purposes only! cPanel may not be able to support the resulting conversion. Please consider whether this is what you want.} );

    delete $cpev->{'_getopt'}{'skip-cpanel-version-check'};
    $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    is(
        dies { $cpev->_blocker_cpanel_needs_update() },
        {
            id  => 2,
            msg => 'This installation of cPanel (11.102.0.5) does not appear to be up to date. Please upgrade cPanel to a most recent version.',
        },
        q{obsolete version generates a blocker.}
    );

    $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.7';
    is( $cpev->_blocker_cpanel_needs_update(), 0, "No blocker if cPanel is up to date" );
    no_messages_seen();
}

{
    note "Distro supported checks.";
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    my $f   = Test::MockFile->symlink( 'linux|centos|6|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
    my $rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

    my $m_custom = Test::MockFile->file(q[/var/cpanel/caches/Cpanel-OS.custom]);

    is(
        dies { $cpev->_blocker_is_non_centos7() },
        {
            id  => 3,
            msg => 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8.',
        },
        'C6 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|8|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is(
        dies { $cpev->_blocker_is_non_centos7() },
        {
            id  => 3,
            msg => 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8.',
        },
        'C8 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|cloudlinux|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is(
        dies { $cpev->_blocker_is_non_centos7() },
        {
            id  => 3,
            msg => 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8.',
        },
        'CL7 is not supported.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|4|2009', '/var/cpanel/caches/Cpanel-OS' );
    like(
        dies { $cpev->_blocker_is_old_centos7() },
        {
            id  => 4,
            msg => qr{You need to run CentOS 7.9 and later to upgrade AlmaLinux 8. You are currently using},
        },
        'Need at least CentOS 7.9.'
    );

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    $m_custom->contents('');
    is(
        dies { $cpev->_blocker_is_experimental_os() },
        {
            id  => 5,
            msg => 'Experimental OS detected. This script only supports CentOS 7 upgrades',
        },
        'Custom OS is not supported.'
    );
    $m_custom->unlink;
    is( $cpev->_blocker_is_experimental_os(), 0, "if not experimental, we're ok" );
    is( $cpev->_blocker_is_non_centos7(),     0, "now on a valid C7" );
    is( $cpev->_blocker_is_old_centos7(),     0, "now on a up to date C7" );

    no_messages_seen();
}

{
    note "Dev sandbox";

    my $f = Test::MockFile->file( '/var/cpanel/dev_sandbox' => '' );

    is(
        dies { $cpev->_blocker_is_sandbox() },
        {
            id  => 6,
            msg => 'Cannot elevate a sandbox...',
        },
        'Dev sandbox is a blocker..'
    );

    $f->unlink;
    is( $cpev->_blocker_is_sandbox(), 0, "if not dev_sandbox, we're ok" );
}

{
    note "Postgresql 9.6/CCS";

    my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
    my %installed = ( 'cpanel-ccs-calendarserver' => 9.2, 'postgresql-server' => 9.2 );
    $pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
    $pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

    is( $cpev->_warning_if_postgresql_installed, 2, "pg 9 is installed" );
    message_seen( 'WARN', "You have postgresql-server version 9.2 installed. This will be upgraded irreversibly to version 10.0 when you switch to AlmaLinux 8" );

    $installed{'postgresql-server'} = '10.2';
    is( $cpev->_warning_if_postgresql_installed, 1, "pg 10 is installed so no warning" );
    no_messages_seen();

    $installed{'postgresql-server'} = 'an_unexpected_version';
    is( $cpev->_warning_if_postgresql_installed, 1, "unknown pg version is installed so no warning" );
    no_messages_seen();

    delete $installed{'postgresql-server'};
    is( $cpev->_warning_if_postgresql_installed, 0, "pg is not installed so no warning" );
    no_messages_seen();

    is(
        dies { $cpev->_blocker_is_calendar_installed() },
        {
            id  => 7,
            msg => "You have the cPanel Calendar Server installed. Upgrades with this server in place are not supported.\nRemoval of this server can lead to data loss.\n",
        },
        'CCS server is a blocker..'
    );
    delete $installed{'cpanel-ccs-calendarserver'};
    is( $cpev->_blocker_is_calendar_installed(), 0, "if CCS isn't installed, we're ok" );
}

{
    is(
        dies { $cpev->_blocker_non_bind_powerdns('nsd') },
        {
            id  => 9,
            msg => <<~'EOS',
    AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns.
    Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
    EOS
        },
        'nsd nameserver is a blocker.'
    );

    is(
        dies { $cpev->_blocker_non_bind_powerdns('mydns') },
        {
            id  => 9,
            msg => <<~'EOS',
    AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns.
    Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
    EOS
        },
        'mydns nameserver is a blocker.'
    );

    is( $cpev->_blocker_non_bind_powerdns('bind'),     0, "if they use bind, we're ok" );
    is( $cpev->_blocker_non_bind_powerdns('powerdns'), 0, "if they use powerdns, we're ok" );
    is( $cpev->_blocker_non_bind_powerdns('disabled'), 0, "if they use no dns, we're ok" );
}

{
    is(
        dies { $cpev->_blocker_old_mysql('5.7') },
        {
            id  => 11,
            msg => <<~'EOS',
    You are using MySQL 5.7 server.
    This version is not available for AlmaLinux 8.
    You first need to update your MySQL server to 8.0 or later.

    You can update to version 8.0 using the following command:

        /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=8.0

    Once the MySQL upgrade is finished, you can then retry to elevate to AlmaLinux 8.
    EOS
        },
        'MySQL 5.7 is a blocker.'
    );

    local $Cpanel::Version::Tiny::major_version = 108;
    is(
        dies { $cpev->_blocker_old_mysql('10.1') },
        {
            id  => 12,
            msg => <<~'EOS',
        You are using MariaDB server 10.1, this version is not available for AlmaLinux 8.
        You first need to update MariaDB server to 10.3 or later.

        You can update to version 10.3 using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.3

        Once the MariaDB upgrade is finished, you can then retry to elevate to AlmaLinux 8.
        EOS
        },
        'Maria 10.1 on 108 is a blocker.'
    );

    $Cpanel::Version::Tiny::major_version = 110;
    is(
        dies { $cpev->_blocker_old_mysql('10.2') },
        {
            id  => 12,
            msg => <<~'EOS',
        You are using MariaDB server 10.2, this version is not available for AlmaLinux 8.
        You first need to update MariaDB server to 10.5 or later.

        You can update to version 10.5 using the following command:

            /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.5

        Once the MariaDB upgrade is finished, you can then retry to elevate to AlmaLinux 8.
        EOS
        },
        'Maria 10.2 on 110 is a blocker.'
    );

    is(
        dies { $cpev->_blocker_old_mysql('4.2') },
        {
            id  => 13,
            msg => <<~'EOS',
        We do not know how to upgrade to AlmaLinux 8 with MySQL version 4.2.
        Please upgrade your MySQL server to one of the supported versions before running elevate.

        Supported MySQL server versions are: 8.0, 10.3, 10.4, 10.5, 10.6
        EOS
        },
        'Maria 10.2 on 110 is a blocker.'
    );

    my $stash = undef;
    $cpev_mock->redefine(
        update_stage_file => sub { $stash = $_[0] },
    );

    is( $cpev->_blocker_old_mysql('8.0'), 0, "MySQL 8 and we're ok" );
    is $stash, { 'mysql-version' => '8.0' }, " - Stash is updated";
    is( $cpev->_blocker_old_mysql('10.3'), 0, "Maria 10.3 and we're ok" );
    is $stash, { 'mysql-version' => '10.3' }, " - Stash is updated";
    is( $cpev->_blocker_old_mysql('10.4'), 0, "Maria 10.4 and we're ok" );
    is $stash, { 'mysql-version' => '10.4' }, " - Stash is updated";
    is( $cpev->_blocker_old_mysql('10.5'), 0, "Maria 10.5 and we're ok" );
    is $stash, { 'mysql-version' => '10.5' }, " - Stash is updated";
    is( $cpev->_blocker_old_mysql('10.6'), 0, "Maria 10.6 and we're ok" );
    is $stash, { 'mysql-version' => '10.6' }, " - Stash is updated";

}

{
    $0 = '/root/elevate-cpanel';
    is(
        dies { $cpev->_blocker_wrong_location() },
        {
            id  => 10,
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{We need elevate-cpanel to live in /scripts/}
    );

    $0 = '';
    is(
        dies { $cpev->_blocker_wrong_location() },
        {
            id  => 10,
            msg => "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n",
        },
        q{Handle if \$0 is broken.}
    );

    $0 = '/scripts/elevate-cpanel';
    is( $cpev->_blocker_wrong_location(), 0, "\$0 can be /scripts/" );
    $0 = '/usr/local/cpanel/scripts/elevate-cpanel';
    is( $cpev->_blocker_wrong_location(), 0, "\$0 can be /usr/local/cpanel/scripts/" );
}

{
    note "checking _sshd_setup";

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    my $sshd_error_message = <<~'EOS';
    OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file, which will default in RHEL8 to "prohibit-password".
    Please set the 'PermitRootLogin' value in /etc/ssh/sshd_config before upgrading.
    EOS

    is cpev::_sshd_setup() => 0, "sshd_config does not exist";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents('');
    is cpev::_sshd_setup() => 0, "sshd_config with empty content";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents( <<~EOS );
    Fruit=cherry
    Veggy=carrot
    EOS
    is cpev::_sshd_setup() => 0, "sshd_config without PermitRootLogin option";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents( <<~EOS );
    Key=value
    PermitRootLogin=yes
    EOS
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin=yes - multilines";

    $mock_sshd_cfg->contents(q[PermitRootLogin=no]);
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin no]);
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin  =  no]);
    is cpev::_sshd_setup() => 1, "sshd_config with PermitRootLogin  =  no";

    $mock_sshd_cfg->contents(q[#PermitRootLogin=no]);
    is cpev::_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=no";
    message_seen( 'ERROR', $sshd_error_message );

    $mock_sshd_cfg->contents(q[#PermitRootLogin=yes]);
    is cpev::_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=yes";
    message_seen( 'ERROR', $sshd_error_message );
}

{
    note "sshd setup check";

    $cpev_mock->redefine( '_sshd_setup' => 0 );
    is(
        dies { $cpev->_blocker_invalid_ssh_config() },
        {
            id  => 16,
            msg => 'Issue with sshd configuration',
        },
        q{Block if sshd is not explicitly configured.}
    );

    $cpev_mock->redefine( '_sshd_setup' => 1 );
    is( $cpev->_blocker_invalid_ssh_config, 0, "no blocker if _sshd_setup is ok" );
    $cpev_mock->unmock('_sshd_setup');
}

{
    note "Jetbackup 4";
    $cpev_mock->redefine( '_use_jetbackup4_or_earlier' => 1 );
    is(
        dies { $cpev->_blocker_old_jetbackup() },
        {
            id  => 17,
            msg => "AlmaLinux 8 does not support JetBackup prior to version 5.\nPlease upgrade JetBackup before elevate.\n",
        },
        q{Block if jetbackup 4 is installed.}
    );

    $cpev_mock->redefine( '_use_jetbackup4_or_earlier' => 0 );
    is( $cpev->_blocker_old_jetbackup(), 0, 'ok when jetbackup 4 or earlier is not installed.' );
    $cpev_mock->unmock('_use_jetbackup4_or_earlier');
}

{
    note "mysql upgrade in progress";
    my $mf_mysql_upgrade = Test::MockFile->file( q[/var/cpanel/mysql_upgrade_in_progress] => 1 );
    is(
        dies { $cpev->_blocker_mysql_upgrade_in_progress() },
        {
            id  => 18,
            msg => "MySQL upgrade in progress. Please wait for the MySQL upgrade to finish.",
        },
        q{Block if mysql is upgrading.}
    );

    $mf_mysql_upgrade->unlink;
    is( $cpev->_blocker_mysql_upgrade_in_progress(), 0, q[MySQL upgrade is not in progress.] );
}

{
    note "system is up to date.";

    $cpev_mock->redefine( _system_update_check => 0 );
    is(
        dies { $cpev->_blocker_system_update() },
        {
            id  => 101,
            msg => "System is not up to date",
        },
        q{Block if the system is not up to date.}
    );

    $cpev_mock->redefine( _system_update_check => 1 );
    is( $cpev->_blocker_system_update(), 0, 'System is up to date' );

    $cpev_mock->unmock('_system_update_check');
}

## Make sure we have NICs that would fail
#my $mock_ip_addr = q{1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
#    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
#    inet 127.0.0.1/8 scope host lo
#       valid_lft forever preferred_lft forever
#    inet6 ::1/128 scope host
#       valid_lft forever preferred_lft forever
#2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
#    link/ether fa:16:3e:98:ea:8d brd ff:ff:ff:ff:ff:ff
#    inet 10.2.67.134/19 brd 10.2.95.255 scope global dynamic eth0
#       valid_lft 28733sec preferred_lft 28733sec
#    inet6 2620:0:28a4:4140:f816:3eff:fe98:ea8d/64 scope global mngtmpaddr dynamic
#       valid_lft 2591978sec preferred_lft 604778sec
#    inet6 fe80::f816:3eff:fe98:ea8d/64 scope link
#       valid_lft forever preferred_lft forever
#3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
#    link/ether fa:16:3e:98:ea:8d brd ff:ff:ff:ff:ff:ff
#    inet 10.2.67.135/19 brd 10.2.95.255 scope global dynamic eth0
#       valid_lft 28733sec preferred_lft 28733sec
#    inet6 2620:0:28a4:4140:f816:3eff:fe98:ea8d/64 scope global mngtmpaddr dynamic
#       valid_lft 2591978sec preferred_lft 604778sec
#    inet6 fe80::f816:3eff:fe98:ea8d/64 scope link
#       valid_lft forever preferred_lft forever
#};

{
    # The NICs blocker runs /sbin/ip which breaks because Cpanel::SafeRun::Simple
    # opens /dev/null which Test::MockFile does not mock and is annoyed by it

    my $sbin_ip = Test::MockFile->file('/sbin/ip');
    note "checking kernel-named NICs";

    # what happens if /sbin/ip is not available
    is(
        dies { $cpev->_blocker_bad_nics_naming() },
        {
            id  => 102,
            msg => 'Missing /sbin/ip binary',
        },
        q{What happens when /sbin/ip is not available}
    );

    # Mock all necessary file access
    my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');
    $errors_mock->redefine( 'saferunnoerror' => '' );
    $sbin_ip->contents('');
    chmod 755, $sbin_ip->path();

    $cpev_mock->redefine( '_get_nics' => sub { qw< eth0 eth1 > } );
    is(
        dies { $cpev->_blocker_bad_nics_naming() },
        {
            id  => 103,
            msg => <<~'EOS',
        Your machine has multiple network interface cards (NICs) using kernel-names (ethX).
        Since the upgrade process cannot guarantee their stability after upgrade, you cannot upgrade.

        Please provide those interfaces new names before continuing the update.
        EOS
        },
        q{What happens when ip addr returns eth0 and eth1}
    );

    $cpev_mock->redefine( '_get_nics' => sub { qw< w0p1lan > } );
    $errors_mock->redefine(
        'saferunnoerror' => sub {
            $_[0] eq '/sbin/ip' ? '' : $errors_mock->original('saferunnoerror');
        }
    );

    is( $cpev->_blocker_bad_nics_naming(), 0, "No blocker with w0p1lan ethernet card" );
}

{
    my $mock_isea4 = Test::MockFile->file( '/etc/cpanel/ea4/is_ea4' => 1 );
    my $type       = '';

    $cpev_mock->redefine(
        backup_ea4_profile => 1,
        _read_stage_file   => sub {
            return {
                ea4 => {
                    dropped_pkgs => {
                        'ea4-bad-pkg' => $type,
                    },
                },
            };
        }
    );

    # only testing the blocking case

    is(
        dies { $cpev->_blocker_ea4_profile() },
        {
            id  => 104,
            msg => <<~'EOS',
        One or more EasyApache 4 package(s) are not compatible with AlmaLinux 8.
        Please remove these packages before continuing the update.
        - ea4-bad-pkg
        EOS

        },
        'blocks when EA4 has an incompatible package'
    );

    message_seen( 'INFO', 'Checking EasyApache profile compatibility with AlmaLinux 8.' );

}

{
    note "checking script update check";

    $script_mock->redefine( '_build_latest_version' => sub { return undef } );

    is(
        dies { $cpev->_check_blocker('UpToDate') },
        {
            id  => 105,
            msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

        },
        "blocks when info about latest version can't be fetched"
    );

    is(
        dies { $cpev->_check_blocker('UpToDate') },
        {
            id  => 105,
            msg => <<~'EOS',
        The script could not fetch information about the latest version.

        Pass the --skip-elevate-version-check flag to skip this check.
        EOS

        },
        "blocks when the installed script isn't the latest release"
    );

    $script_mock->unmock('_build_latest_version');
}

{
    note "checking GRUB_ENABLE_BLSCFG state check";

    $cpev_mock->redefine( _parse_shell_variable => sub { die "something happened\n" } );
    is( dies { $cpev->_blocker_blscfg() }, "something happened\n", "blockers_check() handles an exception when there is a problem parsing /etc/default/grub" );

    $cpev_mock->redefine( _parse_shell_variable => "false" );
    is(
        dies { $cpev->_blocker_blscfg() },
        hash {
            field id  => 106;
            field msg => match qr/^Disabling the BLS boot entry format prevents the resulting system from/;
            end;
        },
        "blocks when the shell variable is set to false"
    );

}

{
    note "grub2 work around.";
    $cpev_mock->redefine( _grub2_workaround_state => cpev::GRUB2_WORKAROUND_UNCERTAIN );
    is(
        dies { $cpev->_blocker_grub2_workaround() },
        hash {
            field id  => 107;
            field msg => match qr/configuration of the GRUB2 bootloader/;
            end;
        },
        "uncertainty about whether GRUB2 workaround is present/needed blocks"
    );

    my $stash = undef;
    $cpev_mock->redefine(
        _grub2_workaround_state => cpev::GRUB2_WORKAROUND_OLD,
        update_stage_file       => sub { $stash = $_[0] },
    );
    is( $cpev->_blocker_grub2_workaround(),                        0, 'Blockers still pass...' );
    is( $stash->{'grub2_workaround'}->{'needs_workaround_update'}, 1, "...but we found the GRUB2 workaround and need to update it" );
    message_seen( 'WARN', qr/instance of the GRUB2 bootloader/ );

    $stash = undef;
    $cpev_mock->redefine( _grub2_workaround_state => cpev::GRUB2_WORKAROUND_NONE );
    $cpev_mock->unmock('update_stage_file');
}

done_testing();
exit;

# We'll test the yum stuff elsewhere

__END__

# Now we've tested the caller, let's test the code.
$cpev_mock->unmock('_yum_is_stable');
my $errors_mock = Test::MockModule->new('Cpanel::SafeRun::Errors');

{
    note "Testing _yum_is_stable";
    my $errors = 'something is not right';
    $errors_mock->redefine( 'saferunonlyerrors' => sub { return $errors } );

    is( cpev::_yum_is_stable(), 0, "Yum is not stable and emits STDERR output (but does not exit non-zero)" );
    message_seen( 'ERROR', 'yum appears to be unstable. Please address this before upgrading' );
    message_seen( 'ERROR', 'something is not right' );
    no_messages_seen();
    $errors = '';

    #TODO Test::MockFile isn't working here.

    # my @stuff;
    # push @stuff, Test::MockFile->dir('/var/lib/yum');

    # is( cpev::_yum_is_stable(), 0, "/var/lib/yum is missing." );
    # message_seen( 'ERROR' => q{Could not read directory '/var/lib/yum': No such file or directory} );

    # mkdir '/var/lib/yum';
    # push @stuff, Test::MockFile->file( '/var/lib/yum/transaction-all.12345', 'aa' );
    # is( cpev::_yum_is_stable(), 0, "There is an outstanding transaction." );
    # message_seen( 'ERROR', 'There are unfinished yum transactions remaining. Please address these before upgrading. The tool `yum-complete-transaction` may help you with this task.' );

    # unlink '/var/lib/yum/transaction-all.12345';
    # is( cpev::_yum_is_stable(), 1, "No outstanding yum transactions are found. we're good to go!" );

}
