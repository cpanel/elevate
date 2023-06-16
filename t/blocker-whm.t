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

my $mock_elevate = Test::MockFile->file('/var/cpanel/elevate');

my $mock_os = Test::MockFile->symlink('linux|centos|7|9|0', '/var/cpanel/caches/Cpanel-OS');
my $mock_os_custom = Test::MockFile->symlink(undef, '/var/cpanel/caches/Cpanel-OS.custom');
my $mock_osr = Test::MockFile->file( '/etc/os-release',     '', { mtime => time - 100000 } );
my $mock_rhr = Test::MockFile->file( '/etc/redhat-release', '', { mtime => time - 100000 } );

my $cpev_mock = Test::MockModule->new('cpev');
my $whm_mock  = Test::MockModule->new('Elevate::Blockers::WHM');

my $cpev = cpev->new;
my $whm  = $cpev->get_blocker('WHM');

# my @mock_locales = Test::MockFile->file('/var/cpanel/server_locale' => q[en] );
# push @mock_locales, Test::MockFile->file('/var/cpanel/locale/en.cdb' => q[] );
# push @mock_locales, Test::MockFile->file('/usr/local/cpanel/Cpanel/Locale.pm' => q[] );
# push @mock_locales, Test::MockFile->dir( '/usr/local/cpanel/Cpanel/Locale' );
# mkdir '/usr/local/cpanel/Cpanel/Locale';
# push @mock_locales, Test::MockFile->file('/var/cpanel/maketext_whitelist' => q[] );
# push @mock_locales, Test::MockFile->file('t/blockers_whm.t' => q[] );

{
    note "cPanel & WHM missing blocker";

    my $mock_cpanel = Test::MockFile->file('/usr/local/cpanel/cpanel');

    is(
        $whm->_blocker_is_missing_cpanel_whm(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_is_missing_cpanel_whm],
            msg => 'This script is only designed to work with cPanel & WHM installs. cPanel & WHM do not appear to be present on your system.',
        },
        "/ULC/cpanel is missing."
    );

    $mock_cpanel->touch;

    is(
        $whm->_blocker_is_missing_cpanel_whm(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_is_missing_cpanel_whm],
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
            id  => q[Elevate::Blockers::WHM::_blocker_is_invalid_cpanel_whm],
            msg => 'Invalid cPanel & WHM major_version.',
        },
        q{no major_version means we're not cPanel?}
    );

    $Cpanel::Version::Tiny::major_version = 106;
    is( $whm->_blocker_is_invalid_cpanel_whm(), 0, '11.106 is unsupported for this script.' );
}

{
    note "cPanel & WHM minimum LTS.";

    local $Cpanel::Version::Tiny::major_version = 100;
    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.109.0.9999';

    like(
        $whm->_blocker_is_newer_than_lts(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_is_newer_than_lts],
            msg => qr{
                    \QThis version 11.109.0.9999 does not support upgrades to AlmaLinux 8.\E \s+
                    \QPlease ensure the cPanel version is 110.\E
                }xms,
        },
        q{cPanel version must be above the known LTS.}
    );

    $Cpanel::Version::Tiny::major_version = Elevate::Constants::MINIMUM_LTS_SUPPORTED;
    is( $whm->_blocker_is_newer_than_lts(), 0, 'Recent LTS version passes this test.' );

}

{
    note "cPanel & WHM license";

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
            id  => q[Elevate::Blockers::WHM::_blocker_cpanel_needs_license],
            msg => qr{for the IP address \Q192.0.2.1\E}m,
        },
        "Blocker message mentions used IP address when check fails",
    );

    $mock_publicip->redefine( get_public_ip => '' );

    like(
        $whm->_blocker_cpanel_needs_license(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_cpanel_needs_license],
            msg => qr{cPanel cannot determine which}m,
        },
        "Blocker message handles case where even public IP lookup fails",
    );
}

{
    note "cPanel & WHM latest version.";
    clear_messages_seen();

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

    local $cpev->{_getopt} = { 'skip-cpanel-version-check' => 1 };

    ok $cpev->getopt('skip-cpanel-version-check'), 'getopt on cpev' or die;
    ok $whm->getopt('skip-cpanel-version-check'),  'getopt on blocker';

    local $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    is( $whm->_blocker_cpanel_needs_update(), 0, "blockers_check() passes with skip-cpanel-version-check specified." );
    message_seen(
        'WARN',
        qr{The --skip-cpanel-version-check option was specified! This option is provided for testing purposes only! cPanel may not be able to support the resulting conversion. Please consider whether this is what you want.}
    );

    delete $cpev->{_getopt};
    ok !$whm->getopt('skip-cpanel-version-check'), 'getopt on blocker';
    $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.5';
    like(
        $whm->_blocker_cpanel_needs_update(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_cpanel_needs_update],
            msg => qr{
                    \QThis installation of cPanel (11.102.0.5) does not appear to be up to date.\E
                    \s+
                    \QPlease upgrade cPanel to a most recent version.\E
                }xms,
        },
        q{obsolete version generates a blocker.}
    );

    clear_messages_seen();

    $Cpanel::Version::Tiny::VERSION_BUILD = '11.102.0.7';
    is( $whm->_blocker_cpanel_needs_update(), 0, "No blocker if cPanel is up to date" );
    no_messages_seen();
}

{
    note "Dev sandbox";

    my $f = Test::MockFile->file( '/var/cpanel/dev_sandbox' => '' );

    is(
        $whm->_blocker_is_sandbox(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_is_sandbox],
            msg => 'Cannot elevate a sandbox...',
        },
        'Dev sandbox is a blocker..'
    );

    $f->unlink;
    is( $whm->_blocker_is_sandbox(), 0, "if not dev_sandbox, we're ok" );
}

{
    note "CCS CalendarServer";

    my $pkgr_mock = Test::MockModule->new('Cpanel::Pkgr');
    my %installed = ( 'cpanel-ccs-calendarserver' => 9.2 );
    $pkgr_mock->redefine( 'is_installed'        => sub ($rpm) { return defined $installed{$rpm} ? 1 : 0 } );
    $pkgr_mock->redefine( 'get_package_version' => sub ($rpm) { return $installed{$rpm} } );

    is(
        $whm->_blocker_is_calendar_installed(),
        {
            id  => q[Elevate::Blockers::WHM::_blocker_is_calendar_installed],
            msg => "You have the cPanel Calendar Server installed. Upgrades with this server in place are not supported.\nRemoval of this server can lead to data loss.\n",
        },
        'CCS server is a blocker..'
    );
    delete $installed{'cpanel-ccs-calendarserver'};
    is( $whm->_blocker_is_calendar_installed(), 0, "if CCS isn't installed, we're ok" );
}

done_testing();
