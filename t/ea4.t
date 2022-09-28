#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use base qw(Test::Class);

use Test::MockFile 0.032;

use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use Cpanel::JSON;

use cPstrict;

use constant PROFILE_FILE => q[/var/my.profile];

__PACKAGE__->new()->runtests() if !caller;

my $stage_file;

sub startup : Test(startup) ($self) {

    $self->{mock_cpev} = Test::MockModule->new('cpev');
    $self->{mock_cpev}->redefine(
        ssystem => sub ( @cmd ) {
            note "mocked ssystem: ", join( ' ', @cmd );
            $self->{last_ssystem_call} = [@cmd];
            return;
        }
    );

    $stage_file = Test::MockFile->file( cpev::ELEVATE_STAGE_FILE() );

    $self->{mock_profile} = Test::MockFile->file(PROFILE_FILE);

    $self->{mock_httpd} = Test::MockModule->new('Cpanel::Config::Httpd');

    return;
}

sub setup : Test(setup) ($self) {

    $self->{mock_httpd}->redefine( is_ea4 => 1 );    # by default
    $stage_file->unlink;

    $self->{mock_profile}->unlink;

    # some tests redefine saferunnoerror
    $self->{mock_saferun} = Test::MockModule->new('Cpanel::SafeRun::Simple');
    $self->{mock_saferun}->redefine(
        saferunnoerror => sub (@cmd) {
            note "mocked: ", join( ' ', @cmd );

            return PROFILE_FILE;
        }
    );

    return;
}

sub teardown : Test( teardown => 1 ) ($self) {

    no_messages_seen();

    return;
}

sub test_backup_and_restore_not_using_ea4 : Test(7) ($self) {

    $self->{mock_httpd}->redefine( is_ea4 => 0 );

    is cpev::backup_ea4_profile(), undef, "backup_ea4_profile - not using ea4";
    message_seen( 'WARN' => q[Skipping EA4 backup. EA4 does not appear to be enabled on this system] );

    is cpev::read_stage_file(), { ea4 => { enable => 0 } }, "stage file - ea4 is disabled";

    is cpev::restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";
    message_seen( 'WARN' => q[Skipping EA4 restore. EA4 does not appear to be enabled on this system.] );

    return;
}

sub test_missing_ea4_profile : Test(3) ($self) {

    $self->{mock_saferun}->redefine(
        saferunnoerror => sub {
            note "saferunnoerror: no output";
            return;
        },
    );

    like(
        dies { cpev::backup_ea4_profile() },
        qr/Unable to backup EA4 profile/,
        "Unable to backup EA4 profile - no profile file"
    );

    _message_run_ea_current_to_profile();

    return;
}

sub test_get_ea4_profile : Test(10) ($self) {

    my $profile = PROFILE_FILE;
    my $output  = qq[$profile\n];

    $self->{mock_profile}->contents('{}');

    $self->{mock_saferun}->redefine(
        saferunnoerror => sub {
            note "saferunnoerror: ", $output;
            return $output;
        },
    );

    is( cpev::_get_ea4_profile(), PROFILE_FILE, "_get_ea4_profile" );
    _message_run_ea_current_to_profile(1);

    $output = <<'EOS';
The following packages are not available on AlmaLinux_8 and have been removed from the profile
    ea-php71
    ea-php71-libc-client
    ea-php71-pear
    ea-php71-php-bcmath
    ea-php71-php-calendar
    ea-php71-php-cli
    ea-php71-php-common
    ea-php71-php-curl
    ea-php71-php-devel
    ea-php71-php-fpm
    ea-php71-php-ftp
    ea-php71-php-gd
    ea-php71-php-iconv
    ea-php71-php-imap
    ea-php71-php-litespeed
    ea-php71-php-mbstring
    ea-php71-php-mysqlnd
    ea-php71-php-pdo
    ea-php71-php-posix
    ea-php71-php-sockets
    ea-php71-php-xml
    ea-php71-php-zip
    ea-php71-runtime

/etc/cpanel/ea4/profiles/custom/current_state_at_2022-04-05_20:41:25_modified_for_AlmaLinux_8.json
EOS

    my $f      = q[/etc/cpanel/ea4/profiles/custom/current_state_at_2022-04-05_20:41:25_modified_for_AlmaLinux_8.json];
    my $mock_f = Test::MockFile->file( $f, '{}' );

    is( cpev::_get_ea4_profile(), $f, "_get_ea4_profile with noise..." );

    _message_run_ea_current_to_profile($f);

    return;
}

sub backup_non_existing_profile : Test(10) ($self) {

    like(
        dies { cpev::backup_ea4_profile() },
        qr/Unable to backup EA4 profile/,
        "Unable to backup EA4 profile - non existing profile file"
    );

    _message_run_ea_current_to_profile();

    $self->{mock_profile}->contents('');

    like(
        dies { cpev::backup_ea4_profile() },
        qr/Unable to backup EA4 profile/,
        "Unable to backup EA4 profile - empty profile file"
    );

    _message_run_ea_current_to_profile();

    is cpev::read_stage_file(), { ea4 => { enable => 1 } }, "stage file - ea4 is enabled but we failed";
    is cpev::restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";

    message_seen( 'WARN' => q[Unable to restore EA4 profile. Is EA4 enabled?] );

    return;
}

sub test_backup_and_restore_ea4_profile : Test(8) ($self) {

    my $profile = { my_profile => ['...'] };

    $self->_update_profile_file($profile);

    is cpev::backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";
    _message_run_ea_current_to_profile(1);

    is cpev::read_stage_file(), { ea4 => { enable => 1, profile => PROFILE_FILE } }, "stage file - ea4 is enabled / profile is backup";

    is cpev::restore_ea4_profile(), 1, "restore_ea4_profile: profile restored";
    is $self->{last_ssystem_call}, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it"
      or diag explain $self->{last_ssystem_call};

    return;
}

sub test_backup_and_restore_ea4_profile_dropped_packages : Test(14) ($self) {

    my $profile = {
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
    $self->_update_profile_file($profile);

    is cpev::backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";
    _message_run_ea_current_to_profile(1);

    is cpev::read_stage_file(), {
        ea4 => {
            enable       => 1,                                        #
            profile      => PROFILE_FILE,                             #
            dropped_pkgs => $profile->{os_upgrade}->{dropped_pkgs}    #
        }
      },
      "stage file - ea4 is enabled / profile is backup with dropped_pkgs";

    is cpev::restore_ea4_profile(), 1, "restore_ea4_profile: profile restored";
    is $self->{last_ssystem_call}, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it"
      or diag explain $self->{last_ssystem_call};

    my $expect = <<'EOS';
One or more EasyApache 4 package(s) cannot be restored from your previous profile:
- 'ea-bar'
- 'ea-baz' ( package was Experimental in CentOS 7 )
EOS
    chomp $expect;
    foreach my $l ( split( "\n", $expect ) ) {
        message_seen( 'WARN' => $l );
    }

    return;
}

sub test_blocker_ea4_profile : Test(16) ($self) {

    $self->{mock_cpev}->redefine( backup_ea4_profile => 0 );

    my $ea_info_check = sub {
        message_seen( 'INFO' => "Checking EasyApache profile compatibility with AlmaLinux 8." );
    };

    my $cpev = bless {}, 'cpev';
    $cpev->{_abort_on_first_blocker} = 1;    # enforce a die

    ok !$cpev->_blocker_ea4_profile(), "no ea4 blockers without an ea4 profile to backup";
    $ea_info_check->();

    $self->{mock_cpev}->redefine( backup_ea4_profile => 1 );

    my $stage_ea4 = {
        profile => '/some/file.not.used.there',
    };
    ok cpev::save_stage_file( { ea4 => $stage_ea4 } ), 'save_stage_file';
    ok !$cpev->_blocker_ea4_profile(), "no ea4 blockers: profile without any dropped_pkgs";
    $ea_info_check->();

    $stage_ea4->{'dropped_pkgs'} = {
        "ea-bar" => "exp",
        "ea-baz" => "exp",
    };
    ok cpev::save_stage_file( { ea4 => $stage_ea4 } ), 'save_stage_file';
    ok !$cpev->_blocker_ea4_profile(), "no ea4 blockers: profile with dropped_pkgs: exp only";
    $ea_info_check->();

    $stage_ea4->{'dropped_pkgs'} = {
        "pkg1"   => "reg",
        "ea-baz" => "exp",
        "pkg3"   => "reg",
        "pkg4"   => "whatever",
    };
    ok cpev::save_stage_file( { ea4 => $stage_ea4 } ), 'save_stage_file';

    ok my $error = dies { $cpev->_blocker_ea4_profile() }, "_blocker_ea4_profile dies";
    $ea_info_check->();

    like $error, object {
        prop blessed => 'cpev::Blocker';

        field id  => 104;
        field msg => 'One or more EasyApache 4 package(s) are not compatible with AlmaLinux 8.
Please remove these packages before continuing the update.
- pkg1
- pkg3
- pkg4
';

        end();
    }, "blocker dies with expected error" or diag explain $error;

    # make sure to restore context
    $self->{mock_cpev}->unmock('backup_ea4_profile');

    return;
}

## helpers

sub _message_run_ea_current_to_profile($success=0) {

    message_seen( 'INFO' => q[Running: /usr/local/bin/ea_current_to_profile --target-os=AlmaLinux_8] );
    return unless $success;

    my $f = $success eq 1 ? PROFILE_FILE : $success;

    message_seen( 'INFO' => q[Backed up EA4 profile to ] . $f );

    return;
}

sub _update_profile_file ( $self, $profile ) {
    my $content = Cpanel::JSON::pretty_canonical_dump($profile);
    $self->{mock_profile}->contents($content);

    return;
}

1;
