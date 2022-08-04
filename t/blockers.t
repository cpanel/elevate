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

require $FindBin::Bin . '/../elevate-cpanel';

my $cpev_mock = Test::MockModule->new('cpev');
$cpev_mock->redefine( _init_logger => sub { die "should not call init_logger" } );

$cpev_mock->redefine( _check_yum_repos => 0 );

$cpev_mock->redefine( '_latest_checksum' => 'HEX', '_self_checksum' => 'HEX' );

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

my $mock_cpanel = Test::MockFile->file('/usr/local/cpanel/cpanel');

# Make sure we have NICs that would fail
my $mock_ip_addr = q{1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether fa:16:3e:98:ea:8d brd ff:ff:ff:ff:ff:ff
    inet 10.2.67.134/19 brd 10.2.95.255 scope global dynamic eth0
       valid_lft 28733sec preferred_lft 28733sec
    inet6 2620:0:28a4:4140:f816:3eff:fe98:ea8d/64 scope global mngtmpaddr dynamic
       valid_lft 2591978sec preferred_lft 604778sec
    inet6 fe80::f816:3eff:fe98:ea8d/64 scope link
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP group default qlen 1000
    link/ether fa:16:3e:98:ea:8d brd ff:ff:ff:ff:ff:ff
    inet 10.2.67.135/19 brd 10.2.95.255 scope global dynamic eth0
       valid_lft 28733sec preferred_lft 28733sec
    inet6 2620:0:28a4:4140:f816:3eff:fe98:ea8d/64 scope global mngtmpaddr dynamic
       valid_lft 2591978sec preferred_lft 604778sec
    inet6 fe80::f816:3eff:fe98:ea8d/64 scope link
       valid_lft forever preferred_lft forever
};

my $mock_isea4 = Test::MockFile->file( '/etc/cpanel/ea4/is_ea4' => 1 );

my $cpconf_mock = Test::MockModule->new('Cpanel::Config::LoadCpConf');
my %cpanel_conf = ( 'local_nameserver_type' => 'nsd', 'mysql-version' => '5.7' );
$cpconf_mock->redefine( 'loadcpconf' => sub { return \%cpanel_conf } );

my $cpev = bless {}, 'cpev';

{
    is( $cpev->blockers_check(), 1, "no major_version means we're not cPanel?" );
    message_seen( 'ERROR', 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.' );
    no_messages_seen();

    $mock_cpanel->touch;

    is( $cpev->blockers_check(), 1, "no major_version means we're not cPanel?" );
    message_seen( 'ERROR', 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.' );
    no_messages_seen();

    $mock_cpanel->chmod(0755);
}

{
    no warnings 'once';
    local $Cpanel::Version::Tiny::major_version;
    is( $cpev->blockers_check(), 1, "no major_version means we're not cPanel?" );
    message_seen( 'ERROR', 'Invalid cPanel & WHM major_version' );
    no_messages_seen();

    $Cpanel::Version::Tiny::major_version = 98;
    is( $cpev->blockers_check(), 2, "11.98 is unsupported for this script." );
    message_seen( 'ERROR', qr/This version 11\.\d+\.\d+\.\d+ does not support upgrades to AlmaLinux 8. Please upgrade to cPanel version 102 or better/a );
    no_messages_seen();
}

{
    no warnings 'once';

    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    is( $cpev->blockers_check(), 2, "cPanel version must match a named tier." );
    message_seen( 'ERROR', qr/does not appear to be up to date/ );
    no_messages_seen();
}

$cpev->{'_getopt'}{'skip-cpanel-version-check'} = 1;
$cpev_mock->redefine( _do_warn_skip_version_check => sub { return } );

{
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    my $f   = Test::MockFile->symlink( 'linux|centos|6|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    my $osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
    my $rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

    my $m_custom = Test::MockFile->file(q[/var/cpanel/caches/Cpanel-OS.custom]);

    is( $cpev->blockers_check(), 3, "C6 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );
    no_messages_seen();

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|8|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $cpev->blockers_check(), 3, "C8 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );
    no_messages_seen();

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|cloudlinux|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $cpev->blockers_check(), 3, "CL7 is not supported." );
    message_seen( 'ERROR', 'This script is only designed to upgrade CentOS 7 to AlmaLinux 8' );
    no_messages_seen();

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|4|2009', '/var/cpanel/caches/Cpanel-OS' );
    is( $cpev->blockers_check(), 4, "Need at least CentOS 7.9." );
    message_seen( 'ERROR', 'You need to run CentOS 7.9 and later to upgrade AlmaLinux 8. You are currently using CentOS v7.4.2009' );
    no_messages_seen();

    undef $f;
    Cpanel::OS::clear_cache_after_cloudlinux_update();
    $f = Test::MockFile->symlink( 'linux|centos|7|9|2009', '/var/cpanel/caches/Cpanel-OS' );
    $m_custom->contents('');
    is( $cpev->blockers_check(), 5, "Custom OS is not supported." );
    message_seen( 'ERROR', 'Experimental OS detected. This script only supports CentOS 7 upgrades' );
    no_messages_seen();
}

# Dev sandbox
my $custom = Test::MockFile->file('/var/cpanel/caches/Cpanel-OS.custom');
my $f      = Test::MockFile->file( '/var/cpanel/dev_sandbox' => '' );

my $elevate_file = Test::MockFile->file('/var/cpanel/elevate');

is( $cpev->blockers_check(), 6, "Dev sandbox is a blocker.." );
message_seen( 'ERROR', 'Cannot elevate a sandbox...' );
no_messages_seen();

$f->unlink;
my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
my %installed = ( 'cpanel-ccs-calendarserver' => 9.2, 'postgresql-server' => 9.2 );
$pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
$pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

is( $cpev->blockers_check(), 7, "CCS Calendar Server is a no go." );
message_seen( 'ERROR', qr{\QYou have the cPanel Calendar Server installed. Upgrades with this server in place are not supported.\E} );
no_messages_seen();

delete $installed{'cpanel-ccs-calendarserver'};
is( $cpev->blockers_check(), 8, "Postgresql 9.2 won't upgrade well." );
message_seen( 'ERROR', <<'EOS' );
You have postgresql-server version 9.2 installed.
This is upgraded irreversably to version 10.0 when you switch to almalinux 8
We recommend data backup and removal of all postgresql packages before upgrade to AlmaLinux 8.
To re-install postgresql 9 on AlmaLinux 8, you can run: `dnf -y module enable postgresql:9.6; dnf -y install postgresql-server`
EOS
no_messages_seen();

$installed{'postgresql-server'} = '10.0';
is( $cpev->blockers_check(), 8, "Postgresql 10 still is blocked." );
message_seen( 'ERROR', <<'EOS' );
You have postgresql-server version 10.0 installed.
We recommend data backup and removal of all postgresql packages before upgrade to AlmaLinux 8.
EOS
no_messages_seen();
%installed = ();

is( $cpev->blockers_check(), 9, "nsd blocks an upgrade to AlmaLinux 8" );
message_seen( 'ERROR', <<'EOS' );
AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns.
Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
EOS
no_messages_seen();

$cpanel_conf{'local_nameserver_type'} = 'mydns';
is( $cpev->blockers_check(), 9, "mydns blocks an upgrade to AlmaLinux 8" );
message_seen( 'ERROR', <<'EOS' );
AlmaLinux 8 only supports bind or powerdns. We suggest you switch to powerdns.
Before upgrading, we suggest you run: /scripts/setupnameserver powerdns.
EOS
no_messages_seen();

$cpanel_conf{'local_nameserver_type'} = 'powerdns';
is( $cpev->blockers_check(), 10, "the script location is incorrect." );
message_seen( 'ERROR', "The script is not installed to the correct directory.\nPlease install it to /scripts/elevate-cpanel and run it again.\n" );
no_messages_seen();

$0 = '/scripts/elevate-cpanel';
is( $cpev->blockers_check(), 11, "the script location is correct but MySQL 5.7 is installed." );
message_seen(
    'ERROR',
    "You are using MySQL 5.7 community server.\nThis version is not available for AlmaLinux 8.\nYou first need to update your MySQL server to 8.0 or later.\n\nYou can update to version 8.0 using the following command:\n\n    /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=8.0\n\nOnce the MySQL upgrade is finished, you can then retry to elevate to AlmaLinux 8.\n"
);
no_messages_seen();

$cpanel_conf{'mysql-version'} = '10.2';
$0 = '/usr/local/cpanel/scripts/elevate-cpanel';
is( $cpev->blockers_check(), 12, "the script location is correct but MariaDB 10.2 is installed." );
message_seen(
    'ERROR',
    "You are using MariaDB server 10.2, this version is not available for AlmaLinux 8.\nYou first need to update MariaDB server to 10.3 or later.\n\nYou can update to version 10.3 using the following command:\n\n    /usr/local/cpanel/bin/whmapi1 start_background_mysql_upgrade version=10.3\n\nOnce the MariaDB upgrade is finished, you can then retry to elevate to AlmaLinux 8.\n"
);
no_messages_seen();

$cpanel_conf{'mysql-version'} = '4.0';
is( $cpev->blockers_check(), 13, 'An Unknown MySQL is present so we block for now.' );
message_seen( 'ERROR', "We do not know how to upgrade to AlmaLinux 8 with MySQL version 4.0.\nPlease open a support ticket.\n" );
no_messages_seen();

$cpanel_conf{'mysql-version'} = '10.3';
$cpev_mock->redefine( _check_yum_repos => 1 );
is( $cpev->blockers_check(), 14, 'An Unknown MySQL is present so we block for now.' );
message_seen( 'ERROR', qr{YUM repo}i );
no_messages_seen();
$cpev_mock->redefine( _check_yum_repos => 0 );

$cpanel_conf{'mysql-version'} = '8.0';
$cpev_mock->redefine( '_yum_is_stable' => 0 );
my $stage_file_updated;
$cpev_mock->redefine( 'save_stage_file' => sub { $stage_file_updated = shift } );
is( $cpev->blockers_check(), 15, 'blocked if yum is not stable.' );
message_seen( 'ERROR', qr{yum is not stable}i );
no_messages_seen();

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

$cpev_mock->redefine( '_disk_space_check' => 1 );
$cpev_mock->redefine( '_yum_is_stable'    => 1 );

$cpev_mock->redefine( '_sshd_setup' => 0 );
is( $cpev->blockers_check(), 16, 'blocked if sshd is not set properly' );
message_seen( 'ERROR', 'Issue with sshd configuration' );
no_messages_seen();
$cpev_mock->redefine( '_sshd_setup' => 1 );

$cpev_mock->redefine( '_use_jetbackup4_or_earlier' => 1 );
is( $cpev->blockers_check(), 17, 'blocked when using jetbackup 4 or earlier' );
message_seen( 'ERROR', qr/Please upgrade JetBackup/ );
no_messages_seen();
$cpev_mock->redefine( '_use_jetbackup4_or_earlier' => 0 );

my $mf_mysql_upgrade = Test::MockFile->file( q[/var/cpanel/mysql_upgrade_in_progress] => 1 );
is( $cpev->blockers_check(), 18, q[MySQL upgrade in progress. Please wait for the MySQL upgrade to finish.] );
message_seen( 'ERROR', q[MySQL upgrade in progress. Please wait for the MySQL upgrade to finish.] );
no_messages_seen();
$mf_mysql_upgrade->unlink;

$cpev_mock->redefine( '_is_container_envtype' => 1 );
is( $cpev->blockers_check(), 90, "Blocks when envtype indicates a container" );
message_seen( 'ERROR', q[cPanel thinks that this is a container-like environment, which this script cannot support at this time.] );
no_messages_seen();
$cpev_mock->redefine( '_is_container_envtype' => 0 );

$cpev_mock->redefine( _system_update_check => 0 );
is( $cpev->blockers_check(), 101, 'System is not up to date' );
message_seen( 'ERROR', 'System is not up to date' );
no_messages_seen();
$cpev_mock->redefine( _system_update_check => 1 );

$cpev_mock->redefine( _system_update_check => 1 );

# The NICs blocker runs /sbin/ip which breaks because Cpanel::SafeRun::Simple
# opens /dev/null which Test::MockFile does not mock and is annoyed by it

my $sbin_ip = Test::MockFile->file('/sbin/ip');
{
    note "checking kernel-named NICs";

    {
        # what happens if /sbin/ip is not available
        is( $cpev->blockers_check(), 102, 'What happens when /sbin/ip is not available' );
        message_seen( 'ERROR', qr/^Missing \S+ binary$/ );
        no_messages_seen();
    }

    # Mock all necessary file access
    $errors_mock->redefine( 'saferunnoerror' => '' );
    $sbin_ip->contents('');
    chmod 755, $sbin_ip->path();

    $cpev_mock->redefine( '_get_nics' => sub { qw< eth0 eth1 > } );
    is( $cpev->blockers_check(), 103, 'What happens when ip addr returns eth0 and eth1' );
    message_seen( 'ERROR', qr/Your machine has multiple network interface cards/ );
    no_messages_seen();

    $cpev_mock->redefine( '_get_nics' => sub { qw< w0p1lan > } );
    $errors_mock->redefine(
        'saferunnoerror' => sub {
            $_[0] eq '/sbin/ip' ? '' : $errors_mock->original('saferunnoerror');
        }
    );

    # tests which used to be here are now handled by the overall "No More Blockers" test below
}

{
    my $type = '';

    $cpev_mock->redefine(
        backup_ea4_profile => 1,
        read_stage_file    => sub {
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
    is( $cpev->blockers_check(), 104, 'blocks when EA4 has an incompatible package' );
    message_seen( 'INFO',  'Checking EasyApache profile compatibility with Almalinux 8.' );
    message_seen( 'ERROR', qr/are not compatible with/ );
    no_messages_seen();

    $cpev_mock->redefine( _blocker_ea4_profile => sub { } );
}

{
    note "checking script update check";

    $cpev_mock->redefine( '_latest_checksum' => sub { undef }, '_self_checksum' => sub { undef } );
    is( $cpev->blockers_check(), 105, "blocks when copy of latest script can't be fetched" );
    message_seen( 'ERROR', qr/latest version of elevate-cpanel could not be fetched for comparison/ );
    no_messages_seen();

    $cpev_mock->redefine( '_latest_checksum' => 'HEX' );
    is( $cpev->blockers_check(), 105, "blocks when the script can't be found at expected location in /scripts" );
    message_seen( 'ERROR', qr/script is not installed at the expected location/ );
    no_messages_seen();

    $cpev_mock->redefine( '_self_checksum' => 'DIFFERENT HEX' );
    is( $cpev->blockers_check(), 105, "blocks when the installed script isn't the latest release" );
    message_seen( 'ERROR', qr/does not appear to be the newest available release/ );
    no_messages_seen();

    $cpev_mock->redefine( '_latest_checksum' => 'HEX', '_self_checksum' => 'HEX' );
}

{
    note "checking GRUB_ENABLE_BLSCFG state check";

    $cpev_mock->redefine( _parse_shell_variable => sub { die "something happened" } );
    is( $cpev->blockers_check(), 127, "blockers_check() handles an exception when there is a problem parsing /etc/default/grub" );
    message_seen( 'WARN', qr/something happened/ );
    no_messages_seen();

    $cpev_mock->redefine( _parse_shell_variable => sub { return undef } );
    is( $cpev->blockers_check(), 106, "blocks when the variable isn't in the file" );
    message_seen( 'ERROR', qr/stored in BLS format upon upgrade/ );
    no_messages_seen();

    $cpev_mock->redefine( _parse_shell_variable => "true" );
    is( $cpev->blockers_check(), 106, "blocks when the variable is set to true" );
    message_seen( 'ERROR', qr/stored in BLS format upon upgrade/ );
    no_messages_seen();

    $cpev_mock->redefine( _parse_shell_variable => "false" );
}

is( $cpev->blockers_check(), 0, 'No More Blockers' );
no_messages_seen();

{
    no warnings 'once';
    $cpev_mock->unmock('_do_warn_skip_version_check');

    $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    is( $cpev->blockers_check(), 0, "blockers_check() passes (w/ WARN) with skip-cpanel-version-check specified, despite obsolete version." );
    message_seen( 'WARN', qr/provided for testing purposes only/ );
    no_messages_seen();

    delete $cpev->{'_getopt'}{'skip-cpanel-version-check'};
    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.7';
    is( $cpev->blockers_check(), 0, "blockers_check() passes without skip-cpanel-version-check specified." );
    no_messages_seen();
}

{
    note "checking _sshd_setup";
    $cpev_mock->unmock('_sshd_setup');

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    is cpev::_sshd_setup() => 0, "sshd_config does not exist";

    $mock_sshd_cfg->contents('');
    is cpev::_sshd_setup() => 0, "sshd_config with empty content";

    $mock_sshd_cfg->contents( <<~EOS );
    Fruit=cherry
    Veggy=carrot
    EOS
    is cpev::_sshd_setup() => 0, "sshd_config without PermitRootLogin option";

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

    $mock_sshd_cfg->contents(q[#PermitRootLogin=yes]);
    is cpev::_sshd_setup() => 0, "sshd_config with commented PermitRootLogin=yes";
}

{
    note "checking _system_update_check";
    my $status = 0;
    my @cmds;
    $cpev_mock->unmock('_system_update_check');
    $cpev_mock->redefine(
        ssystem => sub {
            push @cmds, [@_];
            return $status;
        }
    );

    ok cpev::_system_update_check(), '_system_update_check - success';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update}],
        ['/scripts/sysup']
      ],
      "check yum & sysup";

    @cmds   = ();
    $status = 1;

    is cpev::_system_update_check(), undef, '_system_update_check - failure';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update}],
      ],
      "check yum & abort";

}

done_testing();
exit;
