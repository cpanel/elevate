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

my $ssh = bless {}, 'Elevate::Components::SSH';

{
    note "checking pre_distro_upgrade";

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    $mock_sshd_cfg->contents('');
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), "PermitRootLogin yes\n", 'Added PermitRootLogin to empty config';

    my $pre_contents = "PasswordAuthentication no\nUseDNS no\nDenyGroups cpaneldemo\n";
    $mock_sshd_cfg->contents($pre_contents);
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), $pre_contents . "PermitRootLogin yes\n", 'Added PermitRootLogin when ommited, trailing newline';

    $pre_contents = "PasswordAuthentication no\nUseDNS no\nDenyGroups cpaneldemo";
    $mock_sshd_cfg->contents($pre_contents);
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), $pre_contents . "\nPermitRootLogin yes\n", 'Added PermitRootLogin when ommited, no trailing newline';

    $pre_contents = "PasswordAuthentication no\nPermitRootLogin yes\nUseDNS no\nDenyGroups cpaneldemo";
    $mock_sshd_cfg->contents($pre_contents);
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), $pre_contents, 'Contents unchanged when PermitRootLogin present and active';

    $pre_contents = "PermitRootLogin no\nPasswordAuthentication no\nUseDNS no\nDenyGroups cpaneldemo\n";
    $mock_sshd_cfg->contents($pre_contents);
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), $pre_contents, 'Contents unchanged when PermitRootLogin present and active';

    $pre_contents = "PasswordAuthentication no\n#PermitRootLogin yes\nUseDNS no\nDenyGroups cpaneldemo";
    $mock_sshd_cfg->contents($pre_contents);
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), $pre_contents . "\nPermitRootLogin yes\n", 'Contents updated when PermitRootLogin present but commented out';

    $pre_contents = "# PermitRootLogin no\nPasswordAuthentication no\nUseDNS no\nDenyGroups cpaneldemo\n";
    $mock_sshd_cfg->contents($pre_contents);
    $ssh->pre_distro_upgrade();
    is $mock_sshd_cfg->contents(), $pre_contents . "PermitRootLogin yes\n", 'Contents updated when PermitRootLogin present but commented out';
}

done_testing();
