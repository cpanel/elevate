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

my $ufw      = cpev->get_component('Ufw');
my $mock_ufw = Test::MockModule->new('Elevate::Components::Ufw');

my $ssystem_and_die_params = [];
$mock_ufw->redefine(
    ssystem_and_die => sub {
        shift;
        my @args = @_;
        push @$ssystem_and_die_params, \@args;
        return;
    },
);

my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
$mock_stagefile->redefine(
    update_stage_file => sub { die "should not be called\n"; },
);

{
    note "checking pre_distro_upgrade";

    set_os_to( 'ubuntu', 20 );

    $mock_ufw->redefine(
        upgrade_distro_manually => 1,
    );

    is( $ufw->pre_distro_upgrade(), undef, 'Returns early if the user is updating the OS' );
    is( $ssystem_and_die_params,    [],    'No system commands were called' );
    no_messages_seen();

    $mock_ufw->redefine(
        upgrade_distro_manually => 0,
    );

    set_os_to( 'alma', 8 );

    is( $ufw->pre_distro_upgrade(), undef, 'Returns early if the upgrade method is NOT do-release-upgrade' );
    is( $ssystem_and_die_params,    [],    'No system commands were called' );
    no_messages_seen();

    set_os_to( 'ubuntu', 20 );

    my $mock_sbin_ufw = Test::MockFile->file( '/usr/sbin/ufw', '' );

    is( $ufw->pre_distro_upgrade(), undef, 'Returns early if ufw is not an executable file' );
    is( $ssystem_and_die_params,    [],    'No system commands were called' );
    message_seen( WARN => qr/Unable to\nensure that port 1022 is open as a secondary ssh option/ );
    no_messages_seen();

    chmod 0755, '/usr/sbin/ufw';

    my $ssystem_stdout = [];
    $mock_ufw->redefine(
        ssystem_capture_output => sub {
            return {
                stdout => $ssystem_stdout,
            };
        },
    );

    my $stage_data = {};
    $mock_stagefile->redefine(
        update_stage_file => sub {
            $stage_data = shift @_;
            return;
        },
    );

    $ssystem_stdout = [
        'Status: active',
        '1022/tcp ALLOW Anywhere'
    ];

    is( $ufw->pre_distro_upgrade(), undef, 'Returns early if the firewall is active and port 1022 is open' );
    is( $ssystem_and_die_params,    [],    'No system commands were called' );
    is(
        $stage_data,
        {
            ufw => {
                is_active => 1,
                is_open   => 1,
            },
        },
        'The stage file was updated with the expected data'
    ) or diag explain $stage_data;
    no_messages_seen();

    $ssystem_stdout = [
        'Status: active',
    ];

    is( $ufw->pre_distro_upgrade(), undef, 'Opens the port and reloads the firewall when it is active but the port is not open' );
    is(
        $ssystem_and_die_params,
        [
            [
                '/usr/sbin/ufw',
                'allow',
                '1022/tcp',
            ],
            [
                '/usr/sbin/ufw',
                'reload',
            ],
        ],
        'The expected system calls were made',
    );
    is(
        $stage_data,
        {
            ufw => {
                is_active => 1,
                is_open   => 0,
            },
        },
        'The stage file was updated with the expected data'
    ) or diag explain $stage_data;
    no_messages_seen();

    $ssystem_stdout         = [];
    $ssystem_and_die_params = [];

    is( $ufw->pre_distro_upgrade(), undef, 'Opens the port and activates the firewall when the port is not open and the firewall is not active' );
    is(
        $ssystem_and_die_params,
        [
            [
                '/usr/sbin/ufw',
                'allow',
                '1022/tcp',
            ],
            [
                '/usr/sbin/ufw',
                '--force',
                'enable',
            ],
        ],
        'The expected system calls were made',
    );
    is(
        $stage_data,
        {
            ufw => {
                is_active => 0,
                is_open   => 0,
            },
        },
        'The stage file was updated with the expected data'
    ) or diag explain $stage_data;
    no_messages_seen();
}

{
    note "testing post_distro_upgrade";

    set_os_to( 'ubuntu', 20 );

    my $stage_data = '';
    $mock_stagefile->redefine(
        read_stage_file => sub {
            return $stage_data;
        },
    );

    $ssystem_and_die_params = [];

    is( $ufw->post_distro_upgrade(), undef, 'returns early if there is no stage data for ufw' );
    is( $ssystem_and_die_params,     [],    'No system commands were called' );

    $stage_data = {
        is_active => 1,
        is_open   => 1,
    };

    is( $ufw->post_distro_upgrade(), undef, 'Returns early if the firewall was active and the port was open before we started' );
    is( $ssystem_and_die_params,     [],    'No system commands were called' );

    $stage_data = {
        is_active => 1,
        is_open   => 0,
    };

    my $mock_sbin_ufw = Test::MockFile->file( '/usr/sbin/ufw', '' );

    is( $ufw->post_distro_upgrade(), undef, 'Returns early if the /usr/sbin/ufw script is not executable' );

    chmod 0755, '/usr/sbin/ufw';

    is( $ufw->post_distro_upgrade(), undef, 'Closes the port and returns if the firewall was active prior to starting and the port was NOT open prior to starting' );
    is(
        $ssystem_and_die_params,
        [
            [
                '/usr/sbin/ufw',
                'delete',
                'allow',
                '1022/tcp',
            ],
        ],
        'The expected system calls were made',
    );

    $stage_data = {
        is_active => 0,
        is_open   => 0,
    };

    $ssystem_and_die_params = [];

    is( $ufw->post_distro_upgrade(), undef, 'Closes the port and disables the firewall if the firewall was disabled and the port was closed prior to starting' );
    is(
        $ssystem_and_die_params,
        [
            [
                '/usr/sbin/ufw',
                'delete',
                'allow',
                '1022/tcp',
            ],
            [
                '/usr/sbin/ufw',
                'disable',
            ],
        ],
        'The expected system calls were made',
    );
}

done_testing();
