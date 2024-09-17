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

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $auto_ssl = bless {}, 'Elevate::Components::AutoSSL';

{
    note "Checking pre_distro_upgrade";

    my $is_using_sectigo       = 0;
    my @ssystem_and_die_params = ();

    my $mock_auto_ssl = Test::MockModule->new('Elevate::Components::AutoSSL');
    $mock_auto_ssl->redefine(
        ssystem_and_die => sub {
            shift;
            @ssystem_and_die_params = @_;
            return;
        },
        is_using_sectigo => sub { return $is_using_sectigo; },
    );

    $auto_ssl->pre_distro_upgrade();
    is( \@ssystem_and_die_params, [], 'Autorepair is NOT invoked when NOT using Sectigo' );

    $is_using_sectigo = 1;
    $auto_ssl->pre_distro_upgrade();
    is(
        \@ssystem_and_die_params,
        [qw{/usr/local/cpanel/scripts/autorepair set_autossl_to_lets_encrypt}],
        'Autorepair is invoked when using Sectigo'
    );
}

{
    note "Checking is_using_sectigo";

    my @test_data = (
        "asdfasfd",
        {},
        {
            enabled => undef,
        },
        {
            enabled => 1,
        },
        {
            enabled      => 0,
            display_name => "Let's Encrypt",
        },
        {
            enabled      => 0,
            display_name => "QAPortal BogoSSL",
        },
        {
            enabled      => 1,
            display_name => "Sectigo",
        },
    );

    my $ssl_auto_mock = Test::MockModule->new('Cpanel::SSL::Auto');
    $ssl_auto_mock->redefine(
        'get_all_provider_info' => sub { return @test_data; },
    );

    is(
        Elevate::Components::AutoSSL::is_using_sectigo(),
        1,
        'is_using_sectigo returns true when Sectigo is enabled'
    );

    $test_data[-1]->{enabled} = 0;
    $test_data[-2]->{enabled} = 1;

    is(
        Elevate::Components::AutoSSL::is_using_sectigo(),
        0,
        'is_using_sectigo returns false when Sectigo is NOT enabled'
    );
}

done_testing();
