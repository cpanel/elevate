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

    foreach my $os (qw{ cent alma }) {
        set_os_to($os);

        my $mock_cpanel_pkgr = Test::MockModule->new('Cpanel::Pkgr');
        $mock_cpanel_pkgr->redefine(
            is_installed => sub ($pkg) {
                return ( $pkg eq 'elevate-release' || $pkg eq 'leapp-data-almalinux' ) ? 1 : 0;
            }
        );

        my @cmds;
        my $system_status;
        my $pkgmgr_mock = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
        $pkgmgr_mock->redefine(
            ssystem_and_die => sub ( $, @args ) {
                push @cmds, [@args];
                return $system_status;
            },
            _pkgmgr => '/usr/bin/dnf',
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
}

{
    note "checking _warn_about_other_modules_that_did_not_convert";

    foreach my $os (qw{ cent alma }) {
        set_os_to($os);

        my $mock_packages = {};
        my $mock_rpm      = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
        $mock_rpm->redefine(
            get_installed_pkgs => sub {
                return $mock_packages;
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

        $mock_packages = {
            'foo'                   => 1,
            'bar'                   => 1,
            'finn'                  => '1.el7.x86_64',
            'quinn'                 => '2.el8.x86_64',
            'acronis-backup-cpanel' => 1,
            'kernel'                => '3.10.el7.x86_64',
            'kernel-tools'          => '3.10.el7.x86_64',
        };
        $unconvertedmodules->_warn_about_other_modules_that_did_not_convert();

        my $expected_os_pretty_name = Elevate::OS::upgrade_to_pretty_name();
        my $expected_pkg            = $os eq 'cent' ? 'finn-1.el7.x86_64' : 'quinn-2.el8.x86_64';
        is(
            $message,
            <<"EOS",
The following packages should probably be removed as they will not function on $expected_os_pretty_name

    $expected_pkg

You can remove these by running: yum -y remove $expected_pkg
EOS
            'The expected final notification is added'
        );

        no_messages_seen();
    }
}

done_testing();
