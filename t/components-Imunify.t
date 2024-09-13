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

use Cpanel::JSON ();

my $cpev_mock    = Test::MockModule->new('cpev');
my $imunify_mock = Test::MockModule->new('Elevate::Components::Imunify');

my $cpev    = cpev->new;
my $imunify = $cpev->get_blocker('Imunify');

{
    note 'testing _check_imunify_license';

    my @cmds;
    my @stdout;
    $cpev_mock->redefine(
        ssystem_hide_and_capture_output => sub ( $, @args ) {
            push @cmds, [@args];
            return { status => 0, stdout => \@stdout, stderr => [] };
        },
    );

    my $mf_imunify360_agent = Test::MockFile->file( '/usr/bin/imunify360-agent', '', { mode => 0755, } );

    @stdout = (
        'this is not json',
    );

    my $blocker = $imunify->_check_imunify_license();

    is ref $blocker, 'cpev::Blocker', 'A blocker object is returned when a blocker is found';
    is(
        \@cmds,
        [
            [
                '/usr/bin/imunify360-agent',
                'version',
                '--json',
            ],
        ],
        'The expected system call is made',
    );

    check_blocker_content($blocker);

    undef @cmds;

    my $imunify360_agent_stdout = {
        license => {
            status => Cpanel::JSON::false(),
        }
    };
    my $imunify360_agent_json = Cpanel::JSON::Dump($imunify360_agent_stdout);

    @stdout = (
        $imunify360_agent_json,
    );

    $blocker = $imunify->_check_imunify_license();

    is ref $blocker, 'cpev::Blocker', 'A blocker object is returned when a blocker is found';
    is(
        \@cmds,
        [
            [
                '/usr/bin/imunify360-agent',
                'version',
                '--json',
            ],
        ],
        'The expected system call is made',
    );

    check_blocker_content($blocker);

    undef @cmds;

    $imunify360_agent_stdout = {
        license => {
            status => Cpanel::JSON::true(),
        }
    };
    $imunify360_agent_json = Cpanel::JSON::Dump($imunify360_agent_stdout);

    @stdout = (
        $imunify360_agent_json,
    );

    is $imunify->_check_imunify_license(), undef, 'No blockers are found when Imunify has a valid license';

    $mf_imunify360_agent->unlink;

    is $imunify->_check_imunify_license(), undef, 'The blocker check is skipped when Imunify is not installed';

    no_messages_seen();
}

sub check_blocker_content ($blocker) {

    like(
        $blocker,
        {
            id  => 'Elevate::Components::Imunify::_check_imunify_license',
            msg => qr/^The Imunify license is reporting that it is not currently valid/,
        },
        'The expected blocker is returned'
    );

    message_seen( WARN => qr/The Imunify license is reporting that it is not currently valid/ );

    return;
}

done_testing();
