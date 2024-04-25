#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

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

my $cpev_mock = Test::MockModule->new('cpev');
my $ssh_mock  = Test::MockModule->new('Elevate::Blockers::SSH');

my $cpev = cpev->new;
my $ssh  = $cpev->get_blocker('SSH');

{
    note "checking _check_ssh_config";

    my $mock_sshd_cfg = Test::MockFile->file(q[/etc/ssh/sshd_config]);

    my $sshd_error_message = <<~'EOS';
    OpenSSH configuration file does not explicitly state the option PermitRootLogin in sshd_config file, which will default in RHEL8 to "prohibit-password".
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
