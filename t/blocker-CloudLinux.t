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

my $cpev_mock = Test::MockModule->new('cpev');
my $cl_mock   = Test::MockModule->new('Elevate::Blockers::CloudLinux');

my $cpev = cpev->new;
my $cl   = $cpev->get_blocker('CloudLinux');

{
    note 'testing _check_cloudlinux_license';

    my $cpev_mock = Test::MockModule->new('cpev');

    my $system_status         = 0;
    my $capture_output_status = 0;
    my @cmds;
    my @stdout;
    $cpev_mock->redefine(
        ssystem => sub ( $, @args ) {
            push @cmds, [@args];
            return $system_status;
        },
        ssystem_capture_output => sub ( $, @args ) {
            push @cmds, [@args];
            return { status => $capture_output_status, stdout => \@stdout, stderr => [] };
        },
    );

    set_os_to('cent');
    is $cl->_check_cloudlinux_license(), 0, 'The blocker check is skipped and returns 0 when the OS is CentOS';

    set_os_to('cloud');

    $system_status = 1;

    my $blocker = dies { $cl->_check_cloudlinux_license() };

    is ref $blocker, 'cpev::Blocker', 'A blocker object is returned when a blocker is found';
    is(
        \@cmds,
        [
            [
                '/usr/bin/cldetect',
                '--check-license',
            ],
            [
                '/usr/sbin/rhn_check',
            ],
        ],
        'The expected system commands are called'
    );

    check_blocker_content($blocker);

    $system_status         = 0;
    $capture_output_status = 1;

    $blocker = dies { $cl->_check_cloudlinux_license() };

    check_blocker_content($blocker);

    $capture_output_status = 0;
    @stdout                = (
        'CL license is not ok',
    );

    $blocker = dies { $cl->_check_cloudlinux_license() };

    check_blocker_content($blocker);

    @stdout = (
        'ok',
    );

    is $cl->_check_cloudlinux_license(), 0, 'No blockers are found when CL has a valid license';

    no_messages_seen();
}

sub check_blocker_content ($blocker) {

    like(
        $blocker,
        {
            id  => 'Elevate::Blockers::CloudLinux::_check_cloudlinux_license',
            msg => qr/^The CloudLinux license is reporting that it is not currently valid/,
        },
        'The expected blocker is returned'
    );

    return;
}

done_testing();
