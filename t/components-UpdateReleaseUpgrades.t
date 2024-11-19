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

my $release_upgrades_content = <<'EOF';
# Default behavior for the release upgrader.

[DEFAULT]
# Default prompting and upgrade behavior, valid options:
#
#  never  - Never check for, or allow upgrading to, a new release.
#  normal - Check to see if a new release is available.  If more than one new
#           release is found, the release upgrader will attempt to upgrade to
#           the supported release that immediately succeeds the
#           currently-running release.
#  lts    - Check to see if a new LTS release is available.  The upgrader
#           will attempt to upgrade to the first LTS release available after
#           the currently-running one.  Note that if this option is used and
#           the currently-running release is not itself an LTS release the
#           upgrader will assume prompt was meant to be normal.
Prompt=never
EOF

my $mock_install_script = Test::MockFile->file( '/usr/local/cpanel/install/BlockUbuntuUpgrades.pm', '' );
my $mock_upgrade_file   = Test::MockFile->file( '/etc/update-manager/release-upgrades',             $release_upgrades_content );

my $comp = cpev->new->get_component('UpdateReleaseUpgrades');

{
    note 'pre_distro_upgrade';

    set_os_to('cent');
    is( $comp->pre_distro_upgrade(), undef, 'Returns early on systems that do not use do_release_upgrade to perform the distro upgrade' );
    no_messages_seen();

    set_os_to('ubuntu');
    like( $mock_upgrade_file->contents(), qr/Prompt=never/, 'Update is blocked before pre_distro_upgrade executes' );
    is( $comp->pre_distro_upgrade(), undef, 'Returns undef' );
    message_seen( INFO => qr/Removing install script that blocks upgrades to/ );
    message_seen( INFO => qr/Updating config file to allow upgrades to/ );
    like( $mock_upgrade_file->contents(), qr/Prompt=lts/, 'Update is allowed after pre_distro_upgrade executes' );
}

done_testing();
