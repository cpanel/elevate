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
use Test2::Tools::Mock;

use Test::MockModule qw/strict/;
use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use cPstrict;

my $mock_stage_file = Test::MockFile->file( '/var/cpanel/elevate', '' );

my $ALT_COMMON         = '/etc/yum.repos.d/alt-common-els.repo';
my $ALT_COMMON_ROLLOUT = '/etc/yum.repos.d/alt-common-els-rollout.repo';

my $comp = cpev->new->get_component('ELS');

# What the ELS tooling leaves behind on a CentOS 7 system: the baseurls are
# pinned to el/7 rather than using $releasever.
my $pinned_el7 = <<~'EOS';
[alt-common]
name = alt common Extended Lifecycle Support by TuxCare
baseurl = https://repo.alt.tuxcare.com/alt-common/rpm/el/7/stable/$basearch/
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-TuxCare
gpgcheck=1
EOS

my $expected_el8 = $pinned_el7;
$expected_el8 =~ s{/el/7/}{/el/8/};

my $pinned_rollout_el7 = <<~'EOS';
[alt-common-rollout-1]
name = alt common ELS by TuxCare - Gradual Rollout Slot 1
baseurl = https://rollout.alt.tuxcare.com/alt-common/slot-1/rpm/el/7/$basearch/
enabled=1
skip_if_unavailable=True

[alt-common-rollout-1-bypass]
name = alt common ELS by TuxCare - Gradual Rollout Slot 1 Bypass
baseurl = https://rollout.alt.tuxcare.com/alt-common/slot-1-bypass/rpm/el/7/$basearch/
enabled=0
skip_if_unavailable=True
EOS

my $expected_rollout_el8 = $pinned_rollout_el7;
$expected_rollout_el8 =~ s{/el/7/}{/el/8/}g;

{
    note 'post_distro_upgrade is a noop when the OS does not use ELS';

    set_os_to( 'cloud', 7 );

    my $mock_alt = Test::MockFile->file( $ALT_COMMON, $pinned_el7 );

    is( $comp->post_distro_upgrade(), undef,       'returns early' );
    is( $mock_alt->contents(),        $pinned_el7, 'alt-common repo file is left untouched' );

    no_messages_seen();
}

{
    note 'post_distro_upgrade repoints the alt-common repos at el8';

    set_os_to( 'cent', 7 );

    my $mock_alt     = Test::MockFile->file( $ALT_COMMON,         $pinned_el7 );
    my $mock_rollout = Test::MockFile->file( $ALT_COMMON_ROLLOUT, $pinned_rollout_el7 );

    is( $comp->post_distro_upgrade(), undef, 'post_distro_upgrade succeeds' );

    is( $mock_alt->contents(),     $expected_el8,         'alt-common-els.repo now points at el8' );
    is( $mock_rollout->contents(), $expected_rollout_el8, 'every rollout slot now points at el8' );

    message_seen( 'INFO', "Updated $ALT_COMMON to use the el8 repos." );
    message_seen( 'INFO', "Updated $ALT_COMMON_ROLLOUT to use the el8 repos." );
    no_messages_seen();
}

{
    note 'post_distro_upgrade is idempotent and skips missing files';

    set_os_to( 'cent', 7 );

    my $mock_alt     = Test::MockFile->file( $ALT_COMMON, $expected_el8 );
    my $mock_rollout = Test::MockFile->file($ALT_COMMON_ROLLOUT);            # does not exist

    is( $comp->post_distro_upgrade(), undef, 'post_distro_upgrade succeeds' );

    is( $mock_alt->contents(), $expected_el8, 'already updated file is left alone' );
    ok( !-e $ALT_COMMON_ROLLOUT, 'missing file is not created' );

    message_seen( 'DEBUG', "No el7 baseurl found in $ALT_COMMON; leaving it unchanged." );

    no_messages_seen();
}

{
    note 'unrelated baseurls are not rewritten';

    set_os_to( 'cent', 7 );

    my $unrelated = <<~'EOS';
    [alt-common]
    baseurl = https://repo.alt.tuxcare.com/alt-common/rpm/el7/stable/$basearch/
    #baseurl = https://example.com/el/7/
    enabled=1
    EOS

    my $mock_alt     = Test::MockFile->file( $ALT_COMMON, $unrelated );
    my $mock_rollout = Test::MockFile->file($ALT_COMMON_ROLLOUT);         # does not exist

    is( $comp->post_distro_upgrade(), undef,      'post_distro_upgrade succeeds' );
    is( $mock_alt->contents(),        $unrelated, 'nothing rewritten when no /el/7/ baseurl is present' );

    message_seen( 'DEBUG', "No el7 baseurl found in $ALT_COMMON; leaving it unchanged." );
    no_messages_seen();
}

{
    note 'a failed write warns and does not claim success';

    set_os_to( 'cent', 7 );

    my $mock_alt     = Test::MockFile->file( $ALT_COMMON, $pinned_el7 );
    my $mock_rollout = Test::MockFile->file($ALT_COMMON_ROLLOUT);          # does not exist

    my $mock_slurper = Test::MockModule->new('File::Slurper');
    $mock_slurper->redefine( write_text => sub { die "disk is full\n" } );

    is( $comp->post_distro_upgrade(), undef, 'post_distro_upgrade survives a failed write' );

    like( $mock_alt->contents(), qr{/el/7/}, 'file is left at its original content' );

    message_seen( 'WARN', qr{Could not update \Q$ALT_COMMON\E: disk is full} );
    no_messages_seen();
}

{
    note 'an unreadable file warns and moves on';

    set_os_to( 'cent', 7 );

    my $mock_alt     = Test::MockFile->file( $ALT_COMMON, $pinned_el7 );
    my $mock_rollout = Test::MockFile->file($ALT_COMMON_ROLLOUT);          # does not exist

    my $mock_slurper = Test::MockModule->new('File::Slurper');
    $mock_slurper->redefine( read_text => sub { die "permission denied\n" } );

    is( $comp->post_distro_upgrade(), undef, 'post_distro_upgrade survives an unreadable file' );

    message_seen( 'WARN', qr{Could not read \Q$ALT_COMMON\E: permission denied} );
    no_messages_seen();
}

{
    note 'pre_distro_upgrade removes the centos7 ELS repos';

    set_os_to( 'cent', 7 );

    my $mock_els         = Test::MockFile->file( '/etc/yum.repos.d/centos7-els.repo',         'els' );
    my $mock_els_rollout = Test::MockFile->file( '/etc/yum.repos.d/centos7-els-rollout.repo', 'rollout' );

    my $mock_pkgr = Test::MockModule->new('Cpanel::Pkgr');
    $mock_pkgr->redefine( is_installed => sub { return 0 } );

    is( $comp->pre_distro_upgrade(), undef, 'pre_distro_upgrade succeeds' );

    ok( !-e '/etc/yum.repos.d/centos7-els.repo',         'centos7-els.repo is removed' );
    ok( !-e '/etc/yum.repos.d/centos7-els-rollout.repo', 'centos7-els-rollout.repo is removed' );

    no_messages_seen();
}

{
    note 'pre_distro_upgrade is a noop when the OS does not use ELS';

    set_os_to( 'cloud', 7 );

    my $mock_els = Test::MockFile->file( '/etc/yum.repos.d/centos7-els.repo', 'els' );

    is( $comp->pre_distro_upgrade(), undef, 'returns early' );
    ok( -e '/etc/yum.repos.d/centos7-els.repo', 'centos7-els.repo is left in place' );

    no_messages_seen();
}

done_testing();
