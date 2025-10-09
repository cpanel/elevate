#!/usr/local/cpanel/3rdparty/bin/perl

#                                      Copyright 2025 WebPros International, LLC
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

my $systemd      = cpev->get_component('Systemd');
my $mock_systemd = Test::MockModule->new('Elevate::Components::Systemd');

{
    note 'checking _add_systemd_resolved_config';

    foreach my $os ( Elevate::OS::SUPPORTED_DISTROS() ) {

        my $ssystem = [];
        $mock_systemd->redefine(
            ssystem => sub {
                shift;
                my @args = @_;
                push @$ssystem, \@args;
                return;
            },
        );

        my $mock_safedir = Test::MockModule->new('Cpanel::SafeDir::MK');
        $mock_safedir->redefine(
            safemkdir => 1,
        );

        my $mock_file_slurper = Test::MockModule->new('File::Slurper');
        $mock_file_slurper->redefine(
            write_text => sub { die "do not call this yet\n"; },
        );

        my $mock_cpanel_conf = Test::MockFile->file( '/etc/systemd/resolved.conf.d/cpanel.conf', 'size' );

        is( $systemd->_add_systemd_resolved_config, undef, "Returns early when 'cpanel.conf' exists" );

        unlink '/etc/systemd/resolved.conf.d/cpanel.conf';

        my ( $fs_file, $fs_contents );
        $mock_file_slurper->redefine(
            write_text => sub {
                ( $fs_file, $fs_contents ) = @_;
            },
        );

        my $expected_contents = <<'EOF';
[Resolve]
DNSStubListener=no
EOF

        is( $systemd->_add_systemd_resolved_config, undef,                                      "Updates '/etc/systemd/resolved.conf.d/cpanel.conf' when the file is missing" );
        is( $fs_file,                               '/etc/systemd/resolved.conf.d/cpanel.conf', 'Correct file was updated' );
        is( $fs_contents,                           $expected_contents,                         "'/etc/systemd/resolved.conf.d/cpanel.conf' has the expected contents" );

        is(
            $ssystem,
            [
                [
                    '/usr/bin/systemctl',
                    'daemon-reload',
                ],
                [
                    '/usr/bin/systemctl',
                    'restart',
                    'systemd-resolved',
                ],
            ],
            'The expected system commands were called'
        );
    }
}

{
    note 'Checking _store_etc_resolv_conf_contents';

    foreach my $os ( Elevate::OS::SUPPORTED_DISTROS() ) {

        my $resolv_contents = <<'EOF';
# comment about why
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

        my $mock_resolv_conf = Test::MockFile->file( '/etc/resolv.conf', $resolv_contents );

        my $update_contents;
        my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
        $mock_stagefile->redefine(
            update_stage_file => sub {
                ($update_contents) = @_;
            },
        );

        is( $systemd->_store_etc_resolv_conf_contents(), undef, 'Returns undef if it saves the contents of "/etc/resolv.conf"' );

        is(
            $update_contents,
            {
                etc_resolv_conf => $resolv_contents,
            },
        );

        undef $mock_resolv_conf;
        $mock_resolv_conf = Test::MockFile->symlink( 'nope', '/etc/resolv.conf' );

        $mock_stagefile->redefine(
            update_stage_file => sub { die "Do not call this here\n"; },
        );

        is( $systemd->_store_etc_resolv_conf_contents(), undef, 'Returns early if "/etc/resolv.conf" is already a symlink' );
    }
}

{
    note 'Checking _restore_etc_resolv_conf_contents';

    foreach my $os ( Elevate::OS::SUPPORTED_DISTROS() ) {

        my $resolv_contents = <<'EOF';
# comment about why
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

        my $mock_resolv_conf = Test::MockFile->file( '/etc/resolv.conf', $resolv_contents );

        my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
        $mock_stagefile->redefine(
            read_stage_file => sub { die "Do not call this yet\n"; },
        );

        my $mock_file_slurper = Test::MockModule->new('File::Slurper');
        $mock_file_slurper->redefine(
            write_binary => sub { die "Do not call this yet\n"; },
        );

        is( $systemd->_restore_etc_resolv_conf_contents(), undef, 'Returns early unless "/etc/resolv.conf" is a symlink' );

        undef $mock_resolv_conf;
        $mock_resolv_conf = Test::MockFile->symlink( 'nope', '/etc/resolv.conf' );

        $mock_stagefile->redefine(
            read_stage_file => sub { return; },
        );

        is( $systemd->_restore_etc_resolv_conf_contents(), undef, 'Returns early if the contents to "/etc/resolv.conf" are not stored in the stage file' );

        $mock_stagefile->redefine(
            read_stage_file => sub { return $resolv_contents; },
        );

        my ( $fs_file, $fs_contents );
        $mock_file_slurper->redefine(
            write_binary => sub {
                ( $fs_file, $fs_contents ) = @_;
            },
        );

        is( $systemd->_restore_etc_resolv_conf_contents(), undef,              'Restores the contents of "/etc/resolv.conf" when it is converted to a symlink during the distro upgrade process' );
        is( $fs_file,                                      '/etc/resolv.conf', 'Expected file is written to' );
        is( $fs_contents,                                  $resolv_contents,   'Expected content is restored' );
    }
}

done_testing();

1;
