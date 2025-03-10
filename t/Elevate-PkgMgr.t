#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032 qw<nostrict>;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use Elevate::Usage;

require $FindBin::Bin . '/../elevate-cpanel';

{
    set_os_to_centos_7();

    my $obj = Elevate::PkgMgr::instance();
    isa_ok $obj, 'Elevate::PkgMgr::YUM';

    $Elevate::PkgMgr::PKGUTILITY = undef;
}

{
    set_os_to_cloudlinux_7();

    my $obj = Elevate::PkgMgr::instance();
    isa_ok $obj, 'Elevate::PkgMgr::YUM';

    $Elevate::PkgMgr::PKGUTILITY = undef;
}

{
    set_os_to_ubuntu_20();

    my $obj = Elevate::PkgMgr::instance();
    isa_ok $obj, 'Elevate::PkgMgr::APT';

    $Elevate::PkgMgr::PKGUTILITY = undef;
}

{
    set_os_to_almalinux_8();

    my $obj = Elevate::PkgMgr::instance();
    isa_ok $obj, 'Elevate::PkgMgr::YUM';

    $Elevate::PkgMgr::PKGUTILITY = undef;
}

{
    note 'Test PkgMgr methods';

    my @skip = qw{ factory instance BEGIN PKGUTILITY };

    my @stash = sort keys %{Elevate::PkgMgr::};

    my $package = q[Elevate::PkgMgr];

    foreach my $sub (@stash) {
        next if $sub =~ m{::};
        next if grep { $_ eq $sub } @skip;

        ok( Elevate::PkgMgr::YUM->can($sub), "Elevate::PkgMgr::YUM::$sub" );
        ok( Elevate::PkgMgr::APT->can($sub), "Elevate::PkgMgr::APT::$sub" );
    }
}

{
    note 'Test PkgMgr::APT::makecache filtering';

    set_os_to_ubuntu_20();

    my $mock_pkgmgr = Test::MockModule->new('Elevate::Roles::Run');
    $mock_pkgmgr->redefine(
        ssystem_capture_output => {
            stderr => [
                'something',
                'WARNING: apt does not have a stable CLI interface. Use with caution in scripts.',
                'W: https://wp-toolkit.plesk.com/cPanel/Ubuntu-20.04-x86_64/6.6.4/wp-toolkit/./InRelease: Key is stored in legacy trusted.gpg keyring (/etc/apt/trusted.gpg), see the DEPRECATION section in apt-key(8) for details.',
                'something else',
            ],
        }
    );

    my $obj = Elevate::PkgMgr::instance();
    is( $obj->makecache(), "something\nsomething else", "makecache() filters the stderr text which is irrelevant" );
}

done_testing();
exit;
