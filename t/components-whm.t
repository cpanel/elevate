#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

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

my $cpev_mock = Test::MockModule->new('cpev');
my $whm_mock  = Test::MockModule->new('Elevate::Components::WHM');

my $cpev = cpev->new;
my $whm  = $cpev->get_component('WHM');

{
    note "cPanel & WHM missing blocker";

    my $mock_cpanel = Test::MockFile->file('/usr/local/cpanel/cpanel');

    is(
        $whm->_blocker_is_missing_cpanel_whm(),
        {
            id  => q[Elevate::Components::WHM::_blocker_is_missing_cpanel_whm],
            msg => 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.',
        },
        "/ULC/cpanel is missing."
    );

    $mock_cpanel->touch;

    is(
        $whm->_blocker_is_missing_cpanel_whm(),
        {
            id  => q[Elevate::Components::WHM::_blocker_is_missing_cpanel_whm],
            msg => 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.',
        },
        "/ULC/cpanel is not -x"
    );

    $mock_cpanel->chmod(0755);
    is( $whm->_blocker_is_missing_cpanel_whm(), 0, "/ULC/cpanel is now present and -x" );

}

{
    note "cPanel & WHM not fully populated.";

    no warnings 'once';
    local $Cpanel::Version::Tiny::major_version;
    is(
        $whm->_blocker_is_invalid_cpanel_whm(),
        {
            id  => q[Elevate::Components::WHM::_blocker_is_invalid_cpanel_whm],
            msg => 'Invalid cPanel & WHM major_version.',
        },
        q{no major_version means we're not cPanel?}
    );

    $Cpanel::Version::Tiny::major_version = 106;
    is( $whm->_blocker_is_invalid_cpanel_whm(), 0, '11.106 is unsupported for this script.' );
}

{
    note "cPanel & WHM LTS version is supported for OS.";

    for my $os ( 'cent', 'cloud', 'ubuntu' ) {
        set_os_to($os);
        my $cpev = cpev->new;
        my $whm  = $cpev->get_component('WHM');

        local $Cpanel::Version::Tiny::major_version = 100;
        local $Cpanel::Version::Tiny::VERSION_BUILD = '11.109.0.9999';

        my $expected_target_os       = Elevate::OS::upgrade_to_pretty_name();
        my $expected_upgrade_version = 110;
        $expected_upgrade_version = 118 if $os eq 'ubuntu';
        like(
            $whm->_blocker_lts_is_supported(),
            {
                id  => q[Elevate::Components::WHM::_blocker_lts_is_supported],
                msg => qr{
                    \QThis version 11.109.0.9999 does not support upgrades to $expected_target_os.\E \s+
                    \QPlease ensure the cPanel version is $expected_upgrade_version.\E
                }xms,
            },
            q{cPanel version must be above the known LTS.}
        );

        $Cpanel::Version::Tiny::major_version = Elevate::OS::lts_supported();
        is( $whm->_blocker_lts_is_supported(), 0, 'Recent LTS version passes this test.' );
    }

    set_os_to('ubuntu');

    my $expected_target_os       = Elevate::OS::upgrade_to_pretty_name();
    my $expected_upgrade_version = 118;
    local $Cpanel::Version::Tiny::major_version = 110;
    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.110.0.1';
    like(
        $whm->_blocker_lts_is_supported(),
        {
            id  => q[Elevate::Components::WHM::_blocker_lts_is_supported],
            msg => qr{
                \QThis version 11.110.0.1 does not support upgrades to $expected_target_os.\E \s+
                \QPlease ensure the cPanel version is $expected_upgrade_version.\E
            }xms,
        },
        q{cPanel version must be above the known LTS.}
    );

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os       = Elevate::OS::upgrade_to_pretty_name();
        my $expected_upgrade_version = 110;
        local $Cpanel::Version::Tiny::major_version = 118;
        local $Cpanel::Version::Tiny::VERSION_BUILD = '11.118.0.1';
        like(
            $whm->_blocker_lts_is_supported(),
            {
                id  => q[Elevate::Components::WHM::_blocker_lts_is_supported],
                msg => qr{
                    \QThis version 11.118.0.1 does not support upgrades to $expected_target_os.\E \s+
                    \QPlease ensure the cPanel version is $expected_upgrade_version.\E
                }xms,
            },
            q{cPanel version must be the known LTS.}
        );
    }

}

{
    note 'Named tiers are supported';

    foreach my $os ( 'cent', 'cloud', 'ubuntu' ) {
        set_os_to($os);
        is( Elevate::OS::supports_named_tiers(), 0, "Named tiers are not supported for $os" );
    }

    set_os_to('alma');

    my $mock_tiers = Test::MockModule->new('Cpanel::Update::Tiers');
    $mock_tiers->redefine(
        get_flattened_hash => sub {
            return {
                'edge'    => '11.128.0.1',
                '11.48'   => '11.48.5.3',
                '11.50'   => '11.50.6.2',
                'current' => '11.104.0.11',
                '11.70'   => '11.70.0.69',
                '11.114'  => '11.114.0.15',
                '11.112'  => '11.112.0.8',
                '11.88'   => '11.88.0.17',
                '11.98'   => '11.98.0.13',
                'lts'     => '11.118.0.41',
                '11.34'   => '11.34.2.8',
                '11.102'  => '11.102.0.36',
                '11.46'   => '11.46.4.0',
                '11.60'   => '11.60.0.48',
                'release' => '11.126.0.11',
                '11.128'  => '11.128.0.1',
                '11.42'   => '11.42.1.31',
                '11.104'  => '11.104.0.11',
                'stable'  => '11.124.0.32',
                '11.126'  => '11.126.0.11'
            };
        },
    );

    is( $whm->_blocker_is_named_tier(118), 0, "Returns 0 when the major version matches a named tier (lts)" );
    is( $whm->_blocker_is_named_tier(124), 0, "Returns 0 when the major version matches a named tier (stable)" );
    is( $whm->_blocker_is_named_tier(126), 0, "Returns 0 when the major version matches a named tier (release)" );
    is( $whm->_blocker_is_named_tier(104), 0, "Returns 0 when the major version matches a named tier (current)" );
    is( $whm->_blocker_is_named_tier(128), 0, "Returns 0 when the major version matches a named tier (edge)" );

    like(
        $whm->_blocker_is_named_tier(34),
        {
            id  => q[Elevate::Components::WHM::_blocker_is_named_tier],
            msg => qr{Please ensure the cPanel version is on either LTS, STABLE, RELEASE, CURRENT, or EDGE},
        },
        'Blocker returned when the major version does not match a named tier',
    );
}

{
    note "cPanel & WHM license";

    set_os_to('cent');

    my ( $mock_license, $mock_localip, $mock_publicip ) = map { Test::MockModule->new($_) } qw(
      Cpanel::License
      Cpanel::DIp::MainIP
      Cpanel::NAT
    );

    $mock_license->redefine( is_licensed => 1 );
    $mock_localip->redefine( getmainip   => sub { die "called unexpectedly" } );
    $mock_publicip->redefine( get_public_ip => sub { die "called unexpectedly" } );

    my $result;
    try_ok { $result = $whm->_blocker_cpanel_needs_license() } "License check short-circuited when license present";
    is $result, 0, "License check passed the blocker";

    $mock_license->redefine( is_licensed => 0 );
    $mock_localip->redefine( getmainip   => 'no one cares' );
    $mock_publicip->redefine( get_public_ip => '192.0.2.1' );

    like(
        $whm->_blocker_cpanel_needs_license(),
        {
            id  => q[Elevate::Components::WHM::_blocker_cpanel_needs_license],
            msg => qr{for the IP address \Q192.0.2.1\E}m,
        },
        "Blocker message mentions used IP address when check fails",
    );

    $mock_publicip->redefine( get_public_ip => '' );

    like(
        $whm->_blocker_cpanel_needs_license(),
        {
            id  => q[Elevate::Components::WHM::_blocker_cpanel_needs_license],
            msg => qr{cPanel cannot determine which}m,
        },
        "Blocker message handles case where even public IP lookup fails",
    );
}

{
    note "cPanel & WHM latest version.";
    clear_messages_seen();

    my $latest_lts_version = "11.110.0.15";

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
                "11.110" => [
                    {
                        "build"   => $latest_lts_version,
                        "is_main" => 1,
                        "named"   => ["lts"],
                    }
                ],
            },
        },
    );

    local $cpev->{_getopt} = { 'skip-cpanel-version-check' => 1 };

    ok $cpev->getopt('skip-cpanel-version-check'), 'getopt on cpev' or die;
    ok $whm->getopt('skip-cpanel-version-check'),  'getopt on blocker';

    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    is( $whm->_blocker_cpanel_needs_update(110), 0, "blockers_check() passes with skip-cpanel-version-check specified." );
    message_seen(
        'WARN',
        qr{The --skip-cpanel-version-check option was specified! This option is provided for testing purposes only! cPanel may not be able to support the resulting conversion. Please consider whether this is what you want.}
    );

    delete $cpev->{_getopt};
    ok !$whm->getopt('skip-cpanel-version-check'), 'getopt on blocker';
    $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    like(
        $whm->_blocker_cpanel_needs_update(110),
        {
            id  => q[Elevate::Components::WHM::_blocker_cpanel_needs_update],
            msg => qr{
                    \QThis installation of cPanel (11.102.0.5) does not appear to be up to date.\E
                    \s+
                    \QPlease upgrade cPanel to $latest_lts_version.\E
                }xms,
        },
        q{obsolete version generates a blocker.}
    );

    clear_messages_seen();

    $Cpanel::Version::Tiny::VERSION_BUILD = $latest_lts_version;
    is( $whm->_blocker_cpanel_needs_update(110), 0, "No blocker if cPanel is up to date" );
    no_messages_seen();
}

{
    note "Dev sandbox";

    my $f = Test::MockFile->file( '/var/cpanel/dev_sandbox' => '' );

    is(
        $whm->_blocker_is_sandbox(),
        {
            id  => q[Elevate::Components::WHM::_blocker_is_sandbox],
            msg => 'Cannot elevate a sandbox...',
        },
        'Dev sandbox is a blocker..'
    );

    $f->unlink;
    is( $whm->_blocker_is_sandbox(), 0, "if not dev_sandbox, we're ok" );
}

{
    note 'supports_named_tiers or lts_supported is required';

    foreach my $os ( 'cent', 'cloud', 'ubuntu', 'alma' ) {
        set_os_to($os);

        my $supports_named_tiers = Elevate::OS::supports_named_tiers();
        if ($supports_named_tiers) {
            ok $supports_named_tiers, "$os supports named tiers";
        }
        else {
            my $lts_supported = Elevate::OS::lts_supported();
            like( $lts_supported, qr/^[0-9]+$/, "$os supports $lts_supported" );
        }
    }
}

{
    note 'UPCP is running';

    is( $whm->_blocker_is_upcp_running(), 0, 'should return 0 if not in start mode' );

    local $cpev->{_getopt} = { start => 1 };

    my $mock_cpanel_unix_pid_tiny = Test::MockModule->new('Cpanel::Unix::PID::Tiny');
    $mock_cpanel_unix_pid_tiny->redefine(
        get_pid_from_pidfile => sub { return; },
    );

    is( $whm->_blocker_is_upcp_running(), 0, 'should return 0 if upcp is not running and it is in start mode' );

    $mock_cpanel_unix_pid_tiny->redefine(
        get_pid_from_pidfile => sub { return 42; },
    );

    like(
        dies { $whm->_blocker_is_upcp_running() },
        {
            id  => q[Elevate::Components::WHM::_blocker_is_upcp_running],
            msg => qr{cPanel Update \(upcp\) is currently running}m,
        },
        'should block when upcp is running and it is in start mode'
    );

    # Reset this
    $whm->components->abort_on_first_blocker(0);
}

{
    note 'bin/backup is running';

    is( $whm->_blocker_is_cpanel_backup_running(), 0, 'should return 0 if not in start mode' );

    local $cpev->{_getopt} = { start => 1 };

    my $mock_cpanel_backup_sync = Test::MockModule->new('Cpanel::Backup::Sync');
    $mock_cpanel_backup_sync->redefine(
        handle_already_running => 1,
    );

    is( $whm->_blocker_is_cpanel_backup_running(), 0, 'should return 0 if backup is not running and it is in start mode' );

    $mock_cpanel_backup_sync->redefine(
        handle_already_running => 0,
    );

    like(
        dies { $whm->_blocker_is_cpanel_backup_running() },
        {
            id  => q[Elevate::Components::WHM::_blocker_is_cpanel_backup_running],
            msg => qr{A cPanel backup is currently running}m,
        },
        'should block when backup is running and it is in start mode'
    );

    # Reset this
    $whm->components->abort_on_first_blocker(0);
}

done_testing();
