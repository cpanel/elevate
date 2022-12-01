#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

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

require $FindBin::Bin . '/../elevate-cpanel';

my $cpev_mock = Test::MockModule->new('cpev');
$cpev_mock->redefine( _init_logger => sub { die "should not call init_logger" } );

{
    note "checking _system_update_check";
    my $status = 0;
    my @cmds;
    my @stdout;
    $cpev_mock->redefine(
        ssystem => sub (@args) {
            push @cmds, [@args];
            return $status;
        },
        ssystem_capture_output => sub (@args) {
            push @cmds, [@args];
            return { status => $status, stdout => \@stdout, stderr => [] };
        },
    );

    ok cpev::_system_update_check(), '_system_update_check - success';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update -q}],
        ['/scripts/sysup']
      ],
      "check yum & sysup" or diag explain \@cmds;

    @cmds   = ();
    $status = 1;
    @stdout = (

        # no kernel update => blocker
        'need-to-update-some-packages           1.1-3.el7.cloudlinux      cloudlinux-x86_64-server-update',
        'accelerate-wp.x86_64                   1.1-3.el7.cloudlinux      cloudlinux-x86_64-server-updates',
        'alt-libxml2.x86_64                     2.10.2-1.el7              cloudlinux-x86_64-server-updates',
        'alt-php-config.noarch                  1-48.el7                  cloudlinux-x86_64-server-updates',
        'alt-php-ssa.x86_64                     0.3-6.el7                 cloudlinux-x86_64-server-updates',
        'alt-python27-cllib.x86_64              3.2.34-1.el7.cloudlinux   cloudlinux-x86_64-server-updates',
        'cagefs.x86_64                          7.5.1.1-1.el7.cloudlinux  cloudlinux-x86_64-server-updates',
        'cagefs-safebin.x86_64                  7.5.1.1-1.el7.cloudlinux  cloudlinux-x86_64-server-updates',
        'copy-jdk-configs.noarch                3.3-11.el7_9              cloudlinux-x86_64-server-updates',
        'cpanel-banners-plugin.noarch           1.0.0-8.12.1.cpanel       cpanel-plugins ',
        'cpanel-monitoring-cpanel-plugin.noarch 1.0.2-29.31.1.cpanel      cpanel-plugins ',
        'ea-openssl11.x86_64                    1:1.1.1s-1.el7.cloudlinux cl-ea4         ',
    );

    is cpev::_system_update_check(), undef, '_system_update_check - failure';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update -q}],
      ],
      "check yum & warn; package update required outside of kernel" or diag explain \@cmds;

    @stdout = (

        # kernel update => not a blocker
        'kernel                                  3.10.0-962.3.2.lve1.5.66.el7 cloudlinux-x86_64-server-updates',
    );

    @cmds   = ();
    $status = 1;
    is cpev::_system_update_check(), undef, '_system_update_check - failure';
    is \@cmds, [
        [qw{/usr/bin/yum clean all}],
        [qw{/usr/bin/yum check-update -q}],
        ['/scripts/sysup']
      ],
      "check yum & warn, only view kernel update needed, then check sysup; " or diag explain \@cmds;

}

done_testing();
exit;
