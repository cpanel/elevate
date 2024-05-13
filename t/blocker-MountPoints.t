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

my $cpev = cpev->new;
my $mp   = $cpev->get_blocker('MountPoints');

my @cmds;
my @stdout;
my @stderr;
my $capture_output_status;
$cpev_mock->redefine(
    ssystem_capture_output => sub ( $, @args ) {
        push @cmds, [@args];
        return { status => $capture_output_status, stdout => \@stdout, stderr => \@stderr };
    },
);

{
    note 'Test _check_for_rhel_23449';

    $capture_output_status = 1;
    is( $mp->_check_for_rhel_23449(), undef, 'No blockers are returned when /usr is NOT a separate mount point' );
    is(
        \@cmds,
        [
            [
                '/usr/bin/findmnt',
                '-no',
                'PROPAGATION',
                '/usr',
            ],
        ],
        'The expected command is called',
    ) or diag explain \@cmds;

    $capture_output_status = 0;
    $stdout[0] = 'shared';
    is( $mp->_check_for_rhel_23449(), undef, 'No blockers are returned when /usr is a separate shared mount point' );

    $stdout[0] = 'private';
    my $blocker = $mp->_check_for_rhel_23449();
    like(
        $blocker,
        {
            id  => 'Elevate::Blockers::MountPoints::_check_for_rhel_23449',
            msg => qr/The current filesystem setup on your server will prevent/,
        },
        'A blocker is returned when /usr is a separate private mount point',
    );

    message_seen( WARN => qr/The current filesystem setup on your server will prevent/ );

    no_messages_seen();
}

{
    note 'Test _ensure_mount_dash_a_succeeds';

    undef @cmds;
    undef @stdout;
    undef @stderr;
    $capture_output_status = undef;

    my $mp_mock = Test::MockModule->new('Elevate::Blockers::MountPoints');
    $mp_mock->redefine(
        is_check_mode => 1,
    );

    is( $mp->_ensure_mount_dash_a_succeeds, undef, 'Returns undef when in check mode' );
    is( \@cmds,                             [],    'No commands are executed when in check mode' );

    $mp_mock->redefine(
        is_check_mode => 0,
    );

    $capture_output_status = 0;

    is( $mp->_ensure_mount_dash_a_succeeds, undef, 'Returns undef when mount -a succeeds' );
    is(
        \@cmds,
        [
            [
                '/usr/bin/mount',
                '-a',
            ],
        ],
        'The expected command is called',
    );

    $capture_output_status = 42;
    $stderr[0] = 'mount: mount point does not exist';

    my $blocker = dies { $mp->_ensure_mount_dash_a_succeeds() };
    like(
        $blocker,
        {
            id  => 'Elevate::Blockers::MountPoints::_ensure_mount_dash_a_succeeds',
            msg => qr/The following command failed to execute successfully on your server/,
        },
        'A blocker is returned when mount -a does not execute successfully',
    );

    no_messages_seen();
}

done_testing();
