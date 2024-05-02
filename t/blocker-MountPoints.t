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
my $capture_output_status;
$cpev_mock->redefine(
    ssystem_capture_output => sub ( $, @args ) {
        push @cmds, [@args];
        return { status => $capture_output_status, stdout => \@stdout, stderr => [] };
    },
);

$capture_output_status = 1;
is( $mp->check(), undef, 'No blockers are returned when /usr is NOT a separate mount point' );

$capture_output_status = 0;
$stdout[0] = 'shared';
is( $mp->check(), undef, 'No blockers are returned when /usr is a separate shared mount point' );

$stdout[0] = 'private';
my $blocker = $mp->check();
like(
    $blocker,
    {
        id  => 'Elevate::Blockers::MountPoints::check',
        msg => qr/The current filesystem setup on your server will prevent/,
    },
    'A blocker is returned when /usr is a separate private mount point',
);

message_seen( WARN => qr/The current filesystem setup on your server will prevent/ );

no_messages_seen();

done_testing();
