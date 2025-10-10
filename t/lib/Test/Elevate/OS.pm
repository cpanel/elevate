#!perl

#                                      Copyright 2024 WebPros International, LLC
#                                                           All rights reserved.
# copyright@cpanel.net                                         http://cpanel.net
# This code is subject to the cPanel license. Unauthorized copying is prohibited.

package Test::Elevate::OS;

use cPstrict;

use Test::More;
use Test::MockModule;

use Elevate::OS        ();
use Elevate::StageFile ();

our @ISA = qw(Exporter);

our @EXPORT = qw(
  set_os_to_almalinux_8
  set_os_to_almalinux_9
  set_os_to_centos_7
  set_os_to_cloudlinux_7
  set_os_to_cloudlinux_8
  set_os_to_ubuntu_20
  set_os_to_ubuntu_22
  set_os_to
);

our @EXPORT_OK = @EXPORT;

my $mock_os;

INIT {
    $mock_os = Test::MockModule->new('Elevate::OS');
    $mock_os->redefine(
        _set_cache => 0,
    );
}

sub set_os_to_centos_7 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is CentOS 7';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'CentOS7'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to_cloudlinux_7 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is CloudLinux 7';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'CloudLinux7'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to_ubuntu_20 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is Ubuntu 20';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'Ubuntu20'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to_almalinux_8 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is AlmaLinux 8';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'AlmaLinux8'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to_almalinux_9 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is AlmaLinux 9';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'AlmaLinux9'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to_cloudlinux_8 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is CloudLinux 8';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'CloudLinux8'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to_ubuntu_22 {
    unmock_os();

    note 'Mock Elevate::OS singleton to think this server is Ubuntu 22';

    my $real_read_stage_file = \&Elevate::StageFile::read_stage_file;
    my $mock_stagefile       = Test::MockModule->new('Elevate::StageFile')->redefine(
        read_stage_file => sub { return 'Ubuntu22'; },
    );

    Elevate::OS::name();

    $mock_stagefile->redefine(
        read_stage_file => $real_read_stage_file,
    );

    return;
}

sub set_os_to ( $os, $version ) {
    return set_os_to_centos_7     if $os =~ m/^cent/i   && $version == 7;
    return set_os_to_cloudlinux_7 if $os =~ m/^cloud/i  && $version == 7;
    return set_os_to_almalinux_8  if $os =~ m/^alma/i   && $version == 8;
    return set_os_to_almalinux_9  if $os =~ m/^alma/i   && $version == 9;
    return set_os_to_cloudlinux_8 if $os =~ m/^cloud/i  && $version == 8;
    return set_os_to_ubuntu_20    if $os =~ m/^ubuntu/i && $version == 20;
    return set_os_to_ubuntu_22    if $os =~ m/^ubuntu/i && $version == 22;

    die "Unknown os:  $os $version\n";
}

sub unmock_os {
    note 'Elevate::OS is no longer mocked';
    $Elevate::OS::OS = undef;
}

1;
