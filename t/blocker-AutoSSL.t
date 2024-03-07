#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $ssl_auto_mock = Test::MockModule->new('Cpanel::SSL::Auto');

my $cpev     = cpev->new;
my $auto_ssl = $cpev->get_blocker('AutoSSL');

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
        display_name => 'Let Us Encrypt',
    },
    {
        enabled      => 0,
        display_name => 'QAPortal BogoSSL',
    },
    {
        enabled      => 1,
        display_name => 'Sectigo',
    },
);

$ssl_auto_mock->redefine(
    'get_all_provider_info' => sub { return @test_data; },
);

{
    like(
        $auto_ssl->_check_autossl_provider(),
        {
            id  => q[Elevate::Blockers::AutoSSL::_check_autossl_provider],
            msg => qr/Elevating with the Sectigo provider in place is no longer supported/,
        },
        'Sectigo enabled is a blocker.'
    );

    $test_data[-1]->{enabled} = 0;
    $test_data[-2]->{enabled} = 1;

    is( $auto_ssl->_check_autossl_provider(), 0, 'A different provider is not a blocker' );
}

done_testing();
