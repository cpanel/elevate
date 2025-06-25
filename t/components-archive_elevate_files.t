#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use FindBin;
use lib $FindBin::Bin . "/lib";

use Test::MockFile 0.032;

use Test::Elevate;

use cPstrict;

my %os_hash = (
    alma   => [8],
    cent   => [7],
    cloud  => [ 7, 8 ],
    ubuntu => [20],
);

my $mock_file_copy = Test::MockModule->new('File::Copy');
$mock_file_copy->redefine(
    mv => sub { die "do not call yet\n"; },
);

my $mock_stages = Test::MockModule->new('Elevate::Stages');
$mock_stages->redefine(
    get_stage => sub { die "do not run yet\n"; },
);

my $components = cpev->new()->components;

foreach my $distro ( keys %os_hash ) {
    foreach my $version ( @{ $os_hash{$distro} } ) {
        next if $version == 8;
        set_os_to( $distro, $version );

        is( $components->archive_elevate_files(), undef, 'Returns early unless log archival is needed' );
    }
}

foreach my $distro ( keys %os_hash ) {
    foreach my $version ( @{ $os_hash{$distro} } ) {
        next unless $version == 8;
        set_os_to( $distro, $version );

        $mock_stages->redefine(
            get_stage => 6,
        );

        my $mock_stage_file    = Test::MockFile->file('/var/cpanel/elevate');
        my $mock_blockers_file = Test::MockFile->file('/var/cpanel/elevate-blockers');
        my $mock_elevate_log   = Test::MockFile->file('/var/log/elevate-cpanel.log');

        is( $components->archive_elevate_files(), undef, 'Returns early when there are no files to archive' );

        $mock_stages->redefine(
            get_stage => 1,
        );

        my $path = $distro eq 'alma' ? 'CentOS7-to-AlmaLinux8' : 'CloudLinux7-to-CloudLinux8';

        my $mock_archive_dir    = Test::MockFile->dir('/var/cpanel/elevate_archive');
        my $mock_os_archive_dir = Test::MockFile->dir("/var/cpanel/elevate_archive/$path");

        $mock_stage_file->contents('stuff');
        $mock_blockers_file->contents('foo');
        $mock_elevate_log->contents('bar');

        is( $components->archive_elevate_files(), undef, 'Returns early unless a successful elevate has completed' );

        $mock_stages->redefine(
            get_stage => 6,
        );

        my %archived_files;
        $mock_file_copy->redefine(
            mv => sub {
                $archived_files{ $_[0] } = $_[1];
            },
        );

        is( $components->archive_elevate_files(), undef, 'Successfully archives logs when all preconditions are met' );
        is(
            \%archived_files,
            {
                '/var/cpanel/elevate'          => "/var/cpanel/elevate_archive/$path/_var_cpanel_elevate",
                '/var/cpanel/elevate-blockers' => "/var/cpanel/elevate_archive/$path/_var_cpanel_elevate-blockers",
                '/var/log/elevate-cpanel.log'  => "/var/cpanel/elevate_archive/$path/_var_log_elevate-cpanel.log",
            },
            'The expected logs are archived to the expected archive locations',
        );

    }
}

done_testing;
exit;
