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

my $cpev       = cpev->new;
my $components = Elevate::Components->new( cpev => $cpev );

my $dupe_comp = $cpev->get_component('PackageDupes');

my $saferun_output;
my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine( saferunnoerror => sub { return $saferun_output } );

{
    note "Checking _find_dupes";

    my @test_data = (
        {
            input  => [qw( tar-1.30-9.el8.x86_64 tar-1.30-8.el8.x86_64 )],
            output => {
                tar => bag {
                    item { version => '1.30', release => '8.el8', arch => 'x86_64' };
                    item { version => '1.30', release => '9.el8', arch => 'x86_64' };
                },
            },
        },
        {
            input  => [qw( tar-1.30-9.el8.x86_64 tar-1.30-8.el8.x86_64 tar-1.30-10.el8.x86_64 )],
            output => {
                tar => bag {
                    item { version => '1.30', release => '8.el8',  arch => 'x86_64' };
                    item { version => '1.30', release => '9.el8',  arch => 'x86_64' };
                    item { version => '1.30', release => '10.el8', arch => 'x86_64' };
                },
            },
        },
        {
            input  => [qw( tar-1.30-9.el8.x86_64 tar-1.30-8.el8.x86_64 flarble-69-11.el9.noarch flarble-42.0-1.noarch )],
            output => {
                tar => bag {
                    item { version => '1.30', release => '8.el8', arch => 'x86_64' };
                    item { version => '1.30', release => '9.el8', arch => 'x86_64' };
                },
                flarble => bag {
                    item { version => '42.0', release => '1',      arch => 'noarch' };
                    item { version => '69',   release => '11.el9', arch => 'noarch' };
                },
            },
        },
        {
            input  => [qw( i-can-parse-dashes-correctly-9.0.0-1.x86_64 i-can-parse-dashes-correctly-9.0.0-2.x86_64 )],
            output => {
                'i-can-parse-dashes-correctly' => bag {
                    item { version => '9.0.0', release => '1', arch => 'x86_64' };
                    item { version => '9.0.0', release => '2', arch => 'x86_64' };
                },
            },
        },
    );

    foreach my $case (@test_data) {
        $saferun_output = join "\n", $case->{input}->@*;
        my $pkglist = join ' ', $case->{input}->@*;
        is( { $dupe_comp->_find_dupes() }, $case->{output}, "Test case “$pkglist” yields expected results" );
    }
}

{
    note "Checking _select_packages_for_removal";

    my @test_data = (
        {
            input => {
                tar => [
                    { version => '1.30', release => '8.el8', arch => 'x86_64' },
                    { version => '1.30', release => '9.el8', arch => 'x86_64' },
                ],
            },
            output  => bag { item $_ foreach qw(tar-1.30-9.el8.x86_64) },
            message => "one pair",
        },
        {
            input => {
                tar => [
                    { version => '1.30', release => '8.el8',  arch => 'x86_64' },
                    { version => '1.30', release => '9.el8',  arch => 'x86_64' },
                    { version => '1.30', release => '10.el8', arch => 'x86_64' },
                ],
            },
            output  => bag { item $_ foreach qw(tar-1.30-10.el8.x86_64 tar-1.30-8.el8.x86_64) },
            message => "one triple",
        },
        {
            input => {
                tar => [
                    { version => '1.30', release => '8.el8', arch => 'x86_64' },
                    { version => '1.30', release => '9.el8', arch => 'x86_64' },
                ],
                flarble => [
                    { version => '42.0', release => '1',      arch => 'noarch' },
                    { version => '69',   release => '11.el9', arch => 'noarch' },
                ],
            },
            output  => bag { item $_ foreach qw(tar-1.30-9.el8.x86_64 flarble-69-11.el9.noarch) },
            message => "two pairs",
        },
    );

    foreach my $case (@test_data) {
        is( [ $dupe_comp->_select_packages_for_removal( $case->{input}->%* ) ], $case->{output}, "Test case with $case->{message} yields expected results" );
    }

}

done_testing;
