#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use Cpanel::JSON;

use cPstrict;

my $ssystem;
my $mock_cpev = Test::MockModule->new('cpev');
$mock_cpev->redefine(
    ssystem => sub ( @cmd ) {
        note "mocked ssystem: ", join( ' ', @cmd );
        $ssystem = [@cmd];
        return;
    }
);

my $stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

my $mock_httpd = Test::MockModule->new('Cpanel::Config::Httpd');
$mock_httpd->redefine( is_ea4 => 0 );

is cpev::backup_ea4_profile(), undef, "backup_ea4_profile - not using ea4";
is cpev::read_stage_file(), { ea4 => { enable => 0 } }, "stage file - ea4 is disabled";

is cpev::restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";

$mock_httpd->redefine( is_ea4 => 1 );

my $mock_saferun = Test::MockModule->new('Cpanel::SafeRun::Simple');
$mock_saferun->redefine(
    saferunnoerror => sub (@cmd) {
        note "mocked: ", join( ' ', @cmd );

        return;
    }
);

like(
    dies { cpev::backup_ea4_profile() },
    qr/Unable to backup EA4 profile/,
    "Unable to backup EA4 profile - no profile file"
);

my $profile_file = q[/var/my.profile];
my $mock_profile = Test::MockFile->file($profile_file);

$mock_saferun->redefine(
    saferunnoerror => sub (@cmd) {
        note "mocked: ", join( ' ', @cmd );

        return $profile_file;
    }
);

like(
    dies { cpev::backup_ea4_profile() },
    qr/Unable to backup EA4 profile/,
    "Unable to backup EA4 profile - non existing profile file"
);

$mock_profile->contents('');

like(
    dies { cpev::backup_ea4_profile() },
    qr/Unable to backup EA4 profile/,
    "Unable to backup EA4 profile - empty profile file"
);

is cpev::read_stage_file(), { ea4 => { enable => 1 } }, "stage file - ea4 is enabled but we failed";
is cpev::restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";

## Backup and restore EA4 profile

my $profile = { my_profile => ['...'] };

my $content = Cpanel::JSON::pretty_canonical_dump($profile);
$mock_profile->contents($content);

is cpev::backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";
is cpev::read_stage_file(), { ea4 => { enable => 1, profile => $profile_file } }, "stage file - ea4 is enabled / profile is backup";

is cpev::restore_ea4_profile(), 1, "restore_ea4_profile: profile restored";
is $ssystem, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it" or diag explain $ssystem;

## Backup and restore EA4 profile with dropped_pkgs

$profile = {
    "os_upgrade" => {
        "source_os"          => "<the source OS’s display name>",
        "target_os"          => "<the --target-os=value value>",
        "target_obs_project" => "<the target os’s OBS project>",
        "dropped_pkgs"       => {
            "ea-bar" => "reg",
            "ea-baz" => "exp"
        }
    }
};
$content = Cpanel::JSON::pretty_canonical_dump($profile);
$mock_profile->contents($content);

$stage_file->contents('');

clear_messages_seen();

is cpev::backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";

message_seen( 'INFO' => q[Running: /usr/local/bin/ea_current_to_profile --target-os=AlmaLinux_8] );
message_seen( 'INFO' => q[Backed up EA4 profile to /var/my.profile] );

no_messages_seen();

is cpev::read_stage_file(), {
    ea4 => {
        enable       => 1,                                        #
        profile      => $profile_file,                            #
        dropped_pkgs => $profile->{os_upgrade}->{dropped_pkgs}    #
    }
  },
  "stage file - ea4 is enabled / profile is backup with dropped_pkgs";

no_messages_seen();
clear_messages_seen();

is cpev::restore_ea4_profile(), 1, "restore_ea4_profile: profile restored";
is $ssystem, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it" or diag explain $ssystem;

my $expect = <<'EOS';
One or more EasyApache 4 package(s) cannot be restored from your previous profile:
- 'ea-bar'
- 'ea-baz' ( package was Experimental in CentOS 7 )
EOS
chomp $expect;
message_seen( 'WARN' => $expect );

no_messages_seen();

done_testing();
