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

my $unconvertedmodules = cpev->new->get_component('UnconvertedModules');

{
    note "checking _remove_leapp_packages";

    my $mock_cpanel_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_cpanel_pkgr->redefine(
        is_installed => sub ($pkg) {
            return ( $pkg eq 'elevate-release' || $pkg eq 'leapp-data-almalinux' ) ? 1 : 0;
        }
    );

    my @cmds;
    my $system_status;
    my $cpev_mock = Test::MockModule->new('cpev');
    $cpev_mock->redefine(
        ssystem_and_die => sub ( $, @args ) {
            push @cmds, [@args];
            return $system_status;
        },
    );

    $unconvertedmodules->_remove_leapp_packages();
    is(
        \@cmds,
        [
            [
                '/usr/bin/dnf',
                '-y',
                'remove',
                'elevate-release',
                'leapp-data-almalinux',
            ],
        ],
        'The expected leapp packages are removed',
    );

    message_seen( 'INFO', 'Removing packages provided by leapp' );
    no_messages_seen();
}

{
    note "checking _warn_about_other_modules_that_did_not_convert";

    my @mock_packages;
    my $mock_rpm = Test::MockModule->new('Elevate::RPM');
    $mock_rpm->redefine(
        get_installed_rpms => sub {
            return @mock_packages;
        },
    );

    $unconvertedmodules->_warn_about_other_modules_that_did_not_convert();
    no_messages_seen();

    my $message;
    my $mock_notify = Test::MockModule->new('Elevate::Notify');
    $mock_notify->redefine(
        add_final_notification => sub {
            ($message) = @_;
        },
    );

    @mock_packages = qw{ foo bar finn-el7 acronis-backup-cpanel kernel-3.10.el7.x86_64 kernel-tools-3.10.el7.x86_64 };
    $unconvertedmodules->_warn_about_other_modules_that_did_not_convert();
    is(
        $message,
        <<'EOS',
The following packages should probably be removed as they will not function on AlmaLinux 8

    finn-el7

You can remove these by running: yum -y remove finn-el7
EOS
        'The expected final notification is added'
    );

    no_messages_seen();
}

done_testing();
