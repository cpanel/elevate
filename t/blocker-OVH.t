#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

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

my $myip = q[127.0.0.1];

my $mock_mainip = Test::MockModule->new('Cpanel::DIp::MainIP')->redefine( getmainip => 42 );
my $mock_nat    = Test::MockModule->new('Cpanel::NAT')->redefine( get_public_ip => sub { return $myip } );

my $cpev    = cpev->new;
my $blocker = Elevate::Blockers::OVH->new( cpev => $cpev );

subtest '__is_ovh' => sub {

    {
        my $mock_pvhrc = Test::MockFile->file('/root/.ovhrc');

        is $blocker->__is_ovh(), 0, "no .ovhrc";

        $mock_pvhrc->touch;
        is $blocker->__is_ovh(), 1, "with .ovhrc";
    }

    {
        my $mock_pvhrc = Test::MockFile->file('/root/.ovhrc');

        is $blocker->__is_ovh(), 0, "invalid ip";

        foreach my $ip (qw{54.38.193.69 192.99.6.142}) {
            $myip = $ip;
            is $blocker->__is_ovh(), 1, "IP $ip belongs to OVH";
        }
    }

    return;
};

subtest 'ovh blocker' => sub {
    my $mock_ovh = Test::MockModule->new('Elevate::Blockers::OVH');
    $mock_ovh->redefine( '__is_ovh' => 1 );

    #my $mock_service = Test::MockModule->new('Elevate::Service')->redefine( is_active => 0 );

    my $mock_touchfile = Test::MockFile->file( Elevate::Blockers::OVH::OVH_MONITORING_TOUCH_FILE() );
    $mock_touchfile->touch();
    is $blocker->check(), 0, "no blocker when file already touched";

    $mock_touchfile->unlink();

    #local @Elevate::Blockers::BLOCKERS = qw{ OVH };
    my $blockers = Elevate::Blockers->new( cpev => $cpev );

    like $blockers->_check_single_blocker('OVH'), object {
        prop blessed => 'cpev::Blocker';
        field id => 'Elevate::Blockers::OVH::check';
    }, "blocker when detecting OVH";

    return;
};

done_testing();
