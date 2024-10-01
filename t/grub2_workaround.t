#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use cPstrict;

use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use File::Temp ();

subtest 'Testing _grub2_workaround_state' => sub {
    {
        my $mocked_boot = File::Temp->newdir();
        local $Elevate::Components::Grub2::GRUB2_PREFIX_DEBIAN = "$mocked_boot/grub";
        local $Elevate::Components::Grub2::GRUB2_PREFIX_RHEL   = "$mocked_boot/grub2";
        mkdir "$mocked_boot/grub2";
        system touch => "$mocked_boot/grub2/grub.cfg";

        is(
            Elevate::Components::Grub2::_grub2_workaround_state(),     #
            Elevate::Components::Grub2::GRUB2_WORKAROUND_NONE(),       #
            "no workaround detected when /boot/grub does not exist"    #
        );
    }

    {
        my $mocked_boot = File::Temp->newdir();
        local $Elevate::Components::Grub2::GRUB2_PREFIX_DEBIAN = "$mocked_boot/grub";
        local $Elevate::Components::Grub2::GRUB2_PREFIX_RHEL   = "$mocked_boot/grub2";
        mkdir "$mocked_boot/grub2";
        mkdir "$mocked_boot/grub";
        system touch => "$mocked_boot/grub2/grub.cfg";
        symlink "../grub2/grub.cfg", "$mocked_boot/grub/grub.cfg";

        is(
            Elevate::Components::Grub2::_grub2_workaround_state(),                                                             #
            Elevate::Components::Grub2::GRUB2_WORKAROUND_OLD(),                                                                #
            "old workaround detected when /boot/grub is a directory and /boot/grub/grub.cfg points to /boot/grub2/grub.cfg"    #
        );
    }

    {
        my $mocked_boot = File::Temp->newdir();
        local $Elevate::Components::Grub2::GRUB2_PREFIX_DEBIAN = "$mocked_boot/grub";
        local $Elevate::Components::Grub2::GRUB2_PREFIX_RHEL   = "$mocked_boot/grub2";
        mkdir "$mocked_boot/grub2";
        system touch => "$mocked_boot/grub2/grub.cfg";
        symlink "grub2", "$mocked_boot/grub";

        is(
            Elevate::Components::Grub2::_grub2_workaround_state(),
            Elevate::Components::Grub2::GRUB2_WORKAROUND_NEW(),
            "new workaround detected when /boot/grub is a symlink to /boot/grub2"
        );
    }

    return;
};

subtest 'Testing _update_grub2_workaround_if_needed' => sub {
    {
        my $stagefile_mock = Test::MockModule->new('Elevate::StageFile');

        my $cpev = cpev->new;
        my $g2   = $cpev->get_component('Grub2');

        $stagefile_mock->redefine(
            _read_stage_file => { grub2_workaround => { needs_workaround_update => 0 } },
        );

        try_ok { $g2->_update_grub2_workaround_if_needed() } "calling the function short-circuits when workaround update is not requested";
    }

    subtest "needs workaround, clean run" => sub {

        my $stagefile_mock = Test::MockModule->new('Elevate::StageFile');

        my $cpev = cpev->new;
        my $g2   = $cpev->get_component('Grub2');

        my $mocked_boot = File::Temp->newdir();
        local $Elevate::Components::Grub2::GRUB2_PREFIX_DEBIAN = "$mocked_boot/grub";
        local $Elevate::Components::Grub2::GRUB2_PREFIX_RHEL   = "$mocked_boot/grub2";
        mkdir "$mocked_boot/grub";
        mkdir "$mocked_boot/grub2";
        system touch => "$mocked_boot/grub2/grub.cfg";
        symlink "../grub2/grub.cfg", "$mocked_boot/grub/grub.cfg";

        my $stage_update;
        $stagefile_mock->redefine(
            _read_stage_file  => { grub2_workaround => { needs_workaround_update => 1 } },
            update_stage_file => sub { $stage_update = $_[0]; return 1; },
        );

        my $now = CORE::time();

        ok( -d "$mocked_boot/grub",       "precondition: /boot/grub is a directory" );
        ok( !-e "$mocked_boot/grub-$now", "precondition: /boot/grub-$now (backup directory) does not exist" );

        {
            no warnings qw(once);
            local *CORE::GLOBAL::time = sub { return $now };
            try_ok { $g2->_update_grub2_workaround_if_needed() } "calling the function doesn't die";
        }

        ok( -l "$mocked_boot/grub",      "postcondition: /boot/grub is symlink" );
        ok( -d "$mocked_boot/grub-$now", "postcondition: /boot/grub-$now is a directory" );

        is( $stage_update, { grub2_workaround => { needs_workaround_update => 1, backup_dir => "$mocked_boot/grub-$now" } }, "the stage file was updated as expected" );

        return;
    };

    subtest "needs workaround, recovery run" => sub {
        my $stagefile_mock = Test::MockModule->new('Elevate::StageFile');

        my $cpev = cpev->new;
        my $g2   = $cpev->get_component('Grub2');

        my $mocked_boot = File::Temp->newdir();
        local $Elevate::Components::Grub2::GRUB2_PREFIX_DEBIAN = "$mocked_boot/grub";
        local $Elevate::Components::Grub2::GRUB2_PREFIX_RHEL   = "$mocked_boot/grub2";
        mkdir "$mocked_boot/grub";
        mkdir "$mocked_boot/grub2";
        system touch => "$mocked_boot/grub2/grub.cfg";
        symlink "../grub2/grub.cfg", "$mocked_boot/grub/grub.cfg";

        my $now = CORE::time();
        my $stage_update;
        $stagefile_mock->redefine(
            _read_stage_file  => { grub2_workaround => { needs_workaround_update => 1, backup_dir => "$mocked_boot/grub-$now" } },
            update_stage_file => sub { die 'this should not reached' },
        );

        # The filesystem setup looks the same, because failure to perform symlink() rolls back the rename():
        ok( -d "$mocked_boot/grub",       "precondition: /boot/grub is a directory" );
        ok( !-e "$mocked_boot/grub-$now", "precondition: /boot/grub-$now (backup directory) does not exist" );

        try_ok { $g2->_update_grub2_workaround_if_needed() } "calling the function doesn't die";

        ok( -l "$mocked_boot/grub",      "postcondition: /boot/grub is symlink" );
        ok( -d "$mocked_boot/grub-$now", "postcondition: /boot/grub-$now is a directory" );

        return;
    };
};

subtest 'Testing _merge_grub_directories_if_needed' => sub {

    my $stagefile_mock = Test::MockModule->new('Elevate::StageFile');

    my $cpev = cpev->new;
    my $g2   = $cpev->get_component('Grub2');

    {
        $stagefile_mock->redefine(
            _read_stage_file => { grub2_workaround => { needs_workaround_update => 0 } },
        );

        try_ok { $g2->_merge_grub_directories_if_needed() } "calling the function short-circuits when workaround update is not requested";
    }

    my $now = CORE::time();

    my $mocked_boot = File::Temp->newdir();
    local $Elevate::Components::Grub2::GRUB2_PREFIX_DEBIAN = "$mocked_boot/grub";
    local $Elevate::Components::Grub2::GRUB2_PREFIX_RHEL   = "$mocked_boot/grub2";
    mkdir "$mocked_boot/grub2";
    mkdir "$mocked_boot/grub-$now";
    system touch => "$mocked_boot/grub2/grub.cfg";
    system touch => "$mocked_boot/grub-$now/splash.xpm.gz";
    symlink "../grub2/grub.cfg", "$mocked_boot/grub-$now/grub.cfg";
    symlink "grub2",             "$mocked_boot/grub";

    $stagefile_mock->redefine(
        _read_stage_file => { grub2_workaround => { needs_workaround_update => 1, backup_dir => "$mocked_boot/grub-$now" } },
    );

    ok( -f "$mocked_boot/grub2/grub.cfg",       "precondition: /boot/grub2/grub.cfg is a regular file" );
    ok( !-e "$mocked_boot/grub2/splash.xpm.gz", "precondition: detritus in /boot/grub-$now isn't present in /boot/grub2" );

    try_ok { $g2->_merge_grub_directories_if_needed() } "calling the function doesn't die";

    ok( -f "$mocked_boot/grub2/grub.cfg",      "postcondition: /boot/grub2/grub.cfg is still a regular file" );
    ok( -f "$mocked_boot/grub2/splash.xpm.gz", "postcondition: detritus is now present in /boot/grub2" );

    return;
};

subtest 'Testing _merge_grub_directories_if_needed' => sub {

    my @ran_once;
    my $g2_mock = Test::MockModule->new('Elevate::Components::Grub2');
    $g2_mock->redefine(
        'run_once',
        sub ( $, $name ) {
            push @ran_once, $name;
            return;
        }
    );

    my $cpev = cpev->new;
    my $g2   = $cpev->get_component('Grub2');

    $g2->pre_distro_upgrade;

    is \@ran_once, [
        qw{
          _update_grub2_workaround_if_needed
          _merge_grub_directories_if_needed
        }
      ],
      'run_once expected components';

    return;
};

done_testing;
