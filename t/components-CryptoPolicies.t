#!/usr/local/cpanel/3rdparty/bin/perl
package test::cpev::components;

#                                      Copyright 2025 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use cPstrict;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockModule qw/strict/;

use File::Slurp ();
use File::Temp  ();

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

my $comp = Elevate::Components::CryptoPolicies->new;

my %installed_packages;

{
    note "Testing check() method";

    my $mock_packages = Test::MockModule->new('Cpanel::Pkgr');
    $mock_packages->redefine( is_installed => sub { die "shouldn't be reached!" } );

    # crypto-policies is EL-only
    Test::Elevate::set_os_to_ubuntu_20();
    try_ok { $comp->check() } "Short-circuits on Ubuntu";

    # crypto-policies doesn't exist on C7/CL7
    Test::Elevate::set_os_to_centos_7();
    try_ok { $comp->check() } "Short-circuits on CentOS 7";

    Test::Elevate::set_os_to_cloudlinux_7();
    try_ok { $comp->check() } "Short-circuits on CloudLinux 7";

    Test::Elevate::set_os_to_almalinux_8();
    $mock_packages->redefine( is_installed => sub { return $installed_packages{ $_[0] } // 0 } );
    %installed_packages = (
        'crypto-policies'         => 0,
        'crypto-policies-scripts' => 0,
    );

    like( $comp->check()->msg, qr/ELevate expects to see the crypto-policies/, "Blocks when packages not installed" );

    %installed_packages = (
        'crypto-policies'         => 1,
        'crypto-policies-scripts' => 1,
    );

    my $mock_tool   = File::Temp->new( PERMS => 0644 );
    my $mock_policy = Test::MockModule->new('Elevate::Components::CryptoPolicies');
    $mock_policy->redefine( UPDATE_CRYPTO_POLICIES_PATH => $mock_tool->filename );

    like( $comp->check()->msg, qr/There appear to be some file permission issues/, "Blocks when update-crypto-policies doesn't exist or isn't executable" );

    chmod 0755, $mock_tool->filename;

    foreach my $policy (qw( DEFAULT DEFAULT:SHA1 LEGACY )) {
        $mock_policy->redefine( current_policy => $policy );
        ok( !$comp->check(), "Policy $policy doesn't block" );
    }

    $mock_policy->redefine( current_policy => 'UNRECOGNIZED' );
    like( $comp->check()->msg, qr/The system's cryptographic policy/, "Blocks when policy is unrecognized" );
}

{
    note "Testing pre_distro_upgrade() method";

    my $policy;
    my $mock_policy = Test::MockModule->new('Elevate::Components::CryptoPolicies');
    $mock_policy->redefine(
        set_policy     => sub { $policy = $_[1] },
        current_policy => sub { die "shouldn't be reached!" },
    );

    # Assume that the packages are installed
    my $mock_packages = Test::MockModule->new('Cpanel::Pkgr');
    $mock_packages->redefine( is_installed => sub { return $installed_packages{ $_[0] } // 0 } );
    %installed_packages = (
        'crypto-policies'         => 1,
        'crypto-policies-scripts' => 1,
    );

    # crypto-policies is EL-only
    Test::Elevate::set_os_to_ubuntu_20();
    try_ok { $comp->pre_distro_upgrade() } "Short-circuits on Ubuntu";

    # crypto-policies doesn't exist on C7/CL7
    Test::Elevate::set_os_to_centos_7();
    try_ok { $comp->pre_distro_upgrade() } "Short-circuits on CentOS 7";

    Test::Elevate::set_os_to_cloudlinux_7();
    try_ok { $comp->pre_distro_upgrade() } "Short-circuits on CloudLinux 7";

    Test::Elevate::set_os_to_almalinux_8();
    $mock_policy->redefine( current_policy => sub { return $policy } );

    $policy = 'LEGACY';
    try_ok { $comp->pre_distro_upgrade() } "Short-circuits if policy is LEGACY";

    $policy = 'DEFAULT:SHA1';
    try_ok { $comp->pre_distro_upgrade() } "Short-circuits if policy is already DEFAULT:SHA1";

    $policy = 'UNRECOGNIZED';
    like( dies { $comp->pre_distro_upgrade() }, qr/^Unexpected crypto policy/, "Dies if policy is completely unexpected" );

    my $test_dir    = File::Temp->newdir();
    my $mock_module = $test_dir->dirname . "/SHA1.pmod";
    my $mock_backup = $test_dir->dirname . "/SHA1.pmod.elevate.bak";
    $mock_policy->redefine( CRYPTO_POLICIES_MODULE_PATH => $test_dir->dirname );

    # TODO: I dispise the way I implemented this. Even tests deserve a bit of DRY.
    #
    # Permutations:
    # The given module file may not exist, may exist but be empty, or may exist with content.
    # The given backup file may not exist, or it may exist.
    # The resulting module file could have our content, or it could not.
    # The resulting backup file could exist with the content of the given module file, could exist with the content of the given backup file, or could not exist.
    # The policy should always result in being set to DEFAULT:SHA1.

    # Case: module DNE, backup DNE
    # Expect: our module, backup DNE
    $policy = 'DEFAULT';
    unlink $mock_module;
    unlink $mock_backup;

    try_ok { $comp->pre_distro_upgrade() } "given module DNE and backup DNE, doesn't die";

    ok( -e $mock_module, "module file exists..." );
    is( File::Slurp::read_file($mock_module), $comp->CUSTOM_MODULE_TEXT, "...and has the expected contents" );

    ok( !-e $mock_backup, "backup file DNE" );

    is( $policy, 'DEFAULT:SHA1', "crypto policy set to DEFAULT:SHA1" );

    # Case: module DNE, backup exists
    # Expect: our module, given backup
    #
    $policy = 'DEFAULT';
    unlink $mock_module;
    File::Slurp::write_file( $mock_backup, "something" );

    try_ok { $comp->pre_distro_upgrade() } "given module DNE and backup exists, doesn't die";

    ok( -e $mock_module, "module file exists..." );
    is( File::Slurp::read_file($mock_module), $comp->CUSTOM_MODULE_TEXT, "...and has the expected contents" );

    ok( -e $mock_backup, "backup file exists..." );
    is( File::Slurp::read_file($mock_backup), "something", "...and is unchanged" );

    is( $policy, 'DEFAULT:SHA1', "crypto policy set to DEFAULT:SHA1" );

    # Case: module empty, backup DNE
    # Expect: our module, backup empty
    $policy = 'DEFAULT';
    File::Slurp::write_file( $mock_module, "" );
    unlink $mock_backup;

    try_ok { $comp->pre_distro_upgrade() } "given module empty and backup DNE, doesn't die";

    ok( -e $mock_module, "module file exists..." );
    is( File::Slurp::read_file($mock_module), $comp->CUSTOM_MODULE_TEXT, "...and has the expected contents" );

    ok( -e $mock_backup, "backup file exists..." );
    is( File::Slurp::read_file($mock_backup), "", "...and is empty, like the original" );

    is( $policy, 'DEFAULT:SHA1', "crypto policy set to DEFAULT:SHA1" );

    # Case: module empty, backup exists
    # Expect: our module, given backup
    $policy = 'DEFAULT';
    File::Slurp::write_file( $mock_module, "" );
    File::Slurp::write_file( $mock_backup, "something" );

    try_ok { $comp->pre_distro_upgrade() } "given module empty and backup exists, doesn't die";

    ok( -e $mock_module, "module file exists..." );
    is( File::Slurp::read_file($mock_module), $comp->CUSTOM_MODULE_TEXT, "...and has the expected contents" );

    ok( -e $mock_backup, "backup file exists..." );
    is( File::Slurp::read_file($mock_backup), "something", "...and is unchanged" );

    is( $policy, 'DEFAULT:SHA1', "crypto policy set to DEFAULT:SHA1" );

    # Case: module exists, backup DNE
    # Expect: our module, backup is given module
    $policy = 'DEFAULT';
    File::Slurp::write_file( $mock_module, "something" );
    unlink $mock_backup;

    try_ok { $comp->pre_distro_upgrade() } "given module exists and backup DNE, doesn't die";

    ok( -e $mock_module, "module file exists..." );
    is( File::Slurp::read_file($mock_module), $comp->CUSTOM_MODULE_TEXT, "...and has the expected contents" );

    ok( -e $mock_backup, "backup file exists..." );
    is( File::Slurp::read_file($mock_backup), "something", "...and has the previous contents of the module" );

    is( $policy, 'DEFAULT:SHA1', "crypto policy set to DEFAULT:SHA1" );

    # Case: module exists, backup exists
    # Expect: given module, given backup (i.e., no change; the assumption is that a previous run died during set_policy())
    $policy = 'DEFAULT';
    File::Slurp::write_file( $mock_module, "something" );
    File::Slurp::write_file( $mock_backup, "something else" );

    try_ok { $comp->pre_distro_upgrade() } "given module exists and backup exists, doesn't die";

    ok( -e $mock_module, "module file exists..." );
    is( File::Slurp::read_file($mock_module), "something", "...and is unchanged" );

    ok( -e $mock_backup, "backup file exists..." );
    is( File::Slurp::read_file($mock_backup), "something else", "...and is unchanged" );

    is( $policy, 'DEFAULT:SHA1', "crypto policy set to DEFAULT:SHA1" );
}

{
    note "Testing post_distro_upgrade() method";

    my $mock_policy = Test::MockModule->new('Elevate::Components::CryptoPolicies');
    $mock_policy->redefine( current_policy => sub { die "shouldn't be reached!" } );

    # crypto-policies is EL-only
    Test::Elevate::set_os_to_ubuntu_20();
    try_ok { $comp->post_distro_upgrade() } "Short-circuits on Ubuntu";

    # crypto-policies doesn't exist on C7/CL7
    Test::Elevate::set_os_to_centos_7();
    try_ok { $comp->post_distro_upgrade() } "Short-circuits on CentOS 7";

    Test::Elevate::set_os_to_cloudlinux_7();
    try_ok { $comp->post_distro_upgrade() } "Short-circuits on CloudLinux 7";

    Test::Elevate::set_os_to_almalinux_8();
    $mock_policy->redefine(
        current_policy              => 'LEGACY',
        CRYPTO_POLICIES_MODULE_PATH => sub { die "shouldn't be reached!" },
    );
    try_ok { $comp->post_distro_upgrade() } "Short-circuits if policy is LEGACY";

    my $policy      = 'forgot to change';
    my $test_dir    = File::Temp->newdir();
    my $mock_module = $test_dir->dirname . "/SHA1.pmod";
    $mock_policy->redefine(
        CRYPTO_POLICIES_MODULE_PATH => $test_dir->dirname,
        set_policy                  => sub { $policy = $_[1] },
        current_policy              => $policy,
    );
    system touch => $mock_module;

    try_ok { $comp->post_distro_upgrade() } "Makes it through all the way";
    ok( !-e $mock_module, "Temporary SHA1 module removed" );
    is( $policy, 'DEFAULT:SHA1', "Policy is set to DEFAULT:SHA1" );
}

done_testing;
