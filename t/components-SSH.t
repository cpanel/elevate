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

{
    note "testing check method";

    my $cpev_mock = Test::MockModule->new('cpev');
    my $ssh_mock  = Test::MockModule->new('Elevate::Components::SSH');

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    my $sshd_error_message = <<~'EOS';
    OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file; this may default to "prohibit-password" after upgrading the distro.
    We will set the 'PermitRootLogin' value in /etc/ssh/sshd_config to 'yes' before upgrading.

    EOS

    my $blocker = $ssh->_check_ssh_config();
    is ref $blocker, "cpev::Blocker", "sshd_config does not exist";
    message_seen( 'ERROR', qr/The system could not read the sshd config file/ );
    message_seen( 'WARN',  qr/Elevation Blocker detected/ );

    $mock_sshd_cfg->contents('');
    is $ssh->_check_ssh_config() => 0, "sshd_config with empty content";
    message_seen( 'WARN', $sshd_error_message );

    $mock_sshd_cfg->contents( <<~EOS );
    Fruit=cherry
    Veggy=carrot
    EOS
    is $ssh->_check_ssh_config() => 0, "sshd_config without PermitRootLogin option";
    message_seen( 'WARN', $sshd_error_message );

    $mock_sshd_cfg->contents( <<~EOS );
    Key=value
    PermitRootLogin=yes
    EOS
    is $ssh->_check_ssh_config() => 1, "sshd_config with PermitRootLogin=yes - multilines";

    $mock_sshd_cfg->contents(q[PermitRootLogin=no]);
    is $ssh->_check_ssh_config() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin no]);
    is $ssh->_check_ssh_config() => 1, "sshd_config with PermitRootLogin=no";

    $mock_sshd_cfg->contents(q[PermitRootLogin  =  no]);
    is $ssh->_check_ssh_config() => 1, "sshd_config with PermitRootLogin  =  no";

    $mock_sshd_cfg->contents(q[#PermitRootLogin=no]);
    is $ssh->_check_ssh_config() => 0, "sshd_config with commented PermitRootLogin=no";
    message_seen( 'WARN', $sshd_error_message );

    $mock_sshd_cfg->contents(q[#PermitRootLogin=yes]);
    is $ssh->_check_ssh_config() => 0, "sshd_config with commented PermitRootLogin=yes";
    message_seen( 'WARN', $sshd_error_message );
}

done_testing();
