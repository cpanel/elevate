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

note "checking _use_jetbackup4_or_earlier";

my $myip = q[127.0.0.1];

my $mock_mainip = Test::MockModule->new('Cpanel::DIp::MainIP')->redefine( getmainip => 42 );
my $mock_nat    = Test::MockModule->new('Cpanel::NAT')->redefine( get_public_ip => sub { return $myip } );

my $cpev = bless {}, 'cpev';

subtest '__is_ovh' => sub {

    {
        my $mock_pvhrc = Test::MockFile->file('/root/.ovhrc');

        is $cpev->__is_ovh(), 0, "no .ovhrc";

        $mock_pvhrc->touch;
        is $cpev->__is_ovh(), 1, "with .ovhrc";
    }

    {
        my $mock_pvhrc = Test::MockFile->file('/root/.ovhrc');

        is $cpev->__is_ovh(), 0, "invalid ip";

        foreach my $ip (qw{54.38.193.69 192.99.6.142}) {
            $myip = $ip;
            is $cpev->__is_ovh(), 1, "IP $ip belongs to OVH";
        }
    }

    return;
};

subtest 'ovh blocker' => sub {
    my $mock_cpev = Test::MockModule->new('cpev');
    $mock_cpev->redefine( '__is_ovh' => 1 );

    my $mock_touchfile = Test::MockFile->file( cpev::OVH_MONITORING_TOUCH_FILE() );
    $mock_touchfile->touch();
    is $cpev->_blocker_ovh_monitoring(), 0, "no blocker when file already touched";

    $mock_touchfile->unlink();

    is $cpev->_blocker_ovh_monitoring(), object {
        prop blessed => 'cpev::Blocker';
    }, "blocker when detecting OVH";

    return;
};

done_testing();
