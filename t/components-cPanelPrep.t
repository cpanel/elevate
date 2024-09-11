#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package test::cpev::components;

use FindBin;

use Test2::V0;

use Test::MockFile   qw/strict/;
use Test::MockModule qw/strict/;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

use Elevate::Components::cPanelPrep ();
use Elevate::Constants              ();

my $cpanel_prep = bless {}, 'Elevate::Components::cPanelPrep';

{
    note "Checking pre_distro_upgrade";

    my $mock_scripts_upcp = Test::MockFile->file('/usr/local/cpanel/scripts/upcp');
    my $mock_bin_backup   = Test::MockFile->file('/usr/local/cpanel/bin/backup');

    my $mock_cpanel_prep = Test::MockModule->new('Elevate::Components::cPanelPrep');

    my %called;
    $mock_cpanel_prep->redefine(
        '_disable_all_cpanel_services' => sub { $called{'_disable_all_cpanel_services'} = 1 },
        '_setup_outdated_services'     => sub { $called{'_setup_outdated_services'}     = 1 },
        '_suspend_chkservd'            => sub { $called{'_suspend_chkservd'}            = 1 },
        '_flush_task_queue'            => sub { $called{'_flush_task_queue'}            = 1 },
    );

    $cpanel_prep->pre_distro_upgrade();

    ok( $called{'_disable_all_cpanel_services'}, '_disable_all_cpanel_services() was called' );
    ok( $called{'_setup_outdated_services'},     '_setup_outdated_services() was called' );
    ok( $called{'_suspend_chkservd'},            '_suspend_chkservd() was called' );
    ok( $called{'_flush_task_queue'},            '_flush_task_queue was called' );

    ok( !-e '/usr/local/cpanel/scripts/upcp', '/usr/local/cpanel/scripts/upcp was unlinked' );
    ok( !-e '/usr/local/cpanel/bin/backup',   '/usr/local/cpanel/bin/backup was unlinked' );
}

{
    note "Checking _suspend_chkservd()";
    my $chkservd_suspend_file = Elevate::Constants::CHKSRVD_SUSPEND_FILE();
    my $mock_chksrvd_suspend  = Test::MockFile->file($chkservd_suspend_file);
    $cpanel_prep->_suspend_chkservd();
    ok -e $chkservd_suspend_file, "$chkservd_suspend_file was created";
}

{
    note "Checking _disable_all_cpanel_services";

    my $mock_systemctl_service = Test::MockModule->new('Elevate::SystemctlService');
    $mock_systemctl_service->redefine(
        'new',
        sub {
            my ( $class, %args ) = @_;
            return bless \%args, $class;
        }
    );
    $mock_systemctl_service->redefine( 'disable',    sub { 1 } );
    $mock_systemctl_service->redefine( 'is_enabled', sub { 1 } );

    my @disabled_services;
    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        'update_stage_file',
        sub {
            my $args_ref = shift;
            @disabled_services = @{ $args_ref->{'disabled_cpanel_services'} // [] };
            return;
        }
    );

    $cpanel_prep->_disable_all_cpanel_services();

    is(
        \@disabled_services,
        [
            qw{
              cpanel
              cpcleartaskqueue
              cpdavd
              cpgreylistd
              cphulkd
              cpipv6
              crond
              dnsadmin
              dovecot
              exim
              ipaliases
              lsws
              mailman
              mysqld
              pdns
              proftpd
              queueprocd
              spamd
              tailwatchd
            }
        ],
        'Expected cPanel services were disabled',
    );
}

{
    note "Checking _setup_outdated_services";

    my $mock_service = Test::MockModule->new('Elevate::Service');
    $mock_service->redefine( 'new',        sub { return bless {}, shift } );
    $mock_service->redefine( 'short_name', 'elevate-cpanel' );

    my $outdated_services_file = Elevate::Constants::IGNORE_OUTDATED_SERVICES_FILE;

    my $mock_outdated_services_dir = Test::MockFile->dir( File::Basename::dirname($outdated_services_file) );
    my $mock_outdated_services     = Test::MockFile->file($outdated_services_file);

    ok $cpanel_prep->_setup_outdated_services(), '_setup_outdated_services() succeeded when elevate-cpanel was not present in outdated services file';
    is( $mock_outdated_services->contents(), "elevate-cpanel\n", 'Outdated services file was updated with elevate-cpanel' );
    ok !$cpanel_prep->_setup_outdated_services(), '_setup_outdated_services() failed when elevate-cpanel was present in outdated service files';
}

{
    note "Checking _flush_task_queue";
    my @ssystem_calls;
    my $mock_cpanel_prep = Test::MockModule->new('Elevate::Components::cPanelPrep');
    $mock_cpanel_prep->redefine( 'ssystem' => sub { my $s = shift; push @ssystem_calls, \@_ } );
    $cpanel_prep->_flush_task_queue();
    is( \@ssystem_calls, [ [ '/usr/local/cpanel/bin/servers_queue', 'run' ] ], '“/usr/local/cpanel/servers_queue run” was executed' );
}

done_testing();
