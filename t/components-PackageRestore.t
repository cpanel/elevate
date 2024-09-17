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

my $pkg_restore = cpev->new->component('PackageRestore');

{
    note "Checking pre_distro_upgrade";

    my $stage_file_data;
    my @pkgs_to_check  = qw{ foo bar baz };
    my %installed_pkgs = (
        foo => 1,
        bar => 0,
        baz => 1,
    );
    my $pkgs_checked_for_config_files;
    my %config_files = (
        foo => [qw{ myfile1 myfile2 }],
        baz => [qw{ thisfile thatfile }],
    );

    my $mock_comp = Test::MockModule->new('Elevate::Components::PackageRestore');
    $mock_comp->redefine(
        _get_packages_to_check => sub { return @pkgs_to_check; },
    );

    my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine(
        is_installed => sub { return $installed_pkgs{ $_[0] }; },
    );

    my $mock_rpm = Test::MockModule->new('Elevate::RPM');
    $mock_rpm->redefine(
        get_config_files => sub {
            $pkgs_checked_for_config_files = $_[1];
            return \%config_files;
        },
    );

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        update_stage_file => sub { $stage_file_data = shift; },
    );

    $pkg_restore->pre_distro_upgrade();

    is(
        [ sort @$pkgs_checked_for_config_files ],
        [ sort keys %config_files ],
        'Correctly detects the installed packages'
    );

    is(
        $stage_file_data,
        { 'packages_to_restore' => \%config_files },
        'Correctly detects the config files and updates the stage file'
    );
}

{
    note "Checking post_distro_upgrade";

    my $stage_file_data = {
        foo => [qw{ myfile1 myfile2 }],
        bar => [qw{ thisfile thatfile }],
        baz => [],
    };
    my @dnf_installed;
    my @config_files_restored;

    my $mock_upsf = Test::MockModule->new('Elevate::StageFile');
    $mock_upsf->redefine(
        read_stage_file => sub { return $stage_file_data; },
    );

    my $mock_dnf = Test::MockModule->new('Elevate::DNF');
    $mock_dnf->redefine(
        install => sub { push @dnf_installed, $_[1]; },
    );

    my $mock_rpm = Test::MockModule->new('Elevate::RPM');
    $mock_rpm->redefine(
        restore_config_files => sub {
            my ( $self, @files ) = @_;
            push @config_files_restored, @files;
        },
    );

    $pkg_restore->post_distro_upgrade();

    is(
        [ sort @dnf_installed ],
        [ sort qw{ foo bar baz } ],
        'Attempted to install modules listed in the stage file'
    );

    is(
        [ sort @config_files_restored ],
        [ sort qw{ myfile1 myfile2 thisfile thatfile } ],
        'Attempted to restore all the appropriate config files'
    )

}

done_testing();
