#!/usr/local/cpanel/3rdparty/bin/perl

package test::cpev::blockers;

use FindBin;

use Test2::V0;
use Test2::Tools::Explain;
use Test2::Plugin::NoWarnings;
use Test2::Tools::Exception;

use base qw(Test::Class);

use Test::MockFile 0.032 plugin => 'FileTemp';
use lib $FindBin::Bin . "/lib";
use Test::Elevate;

use Test::MockModule qw/strict/;

use Cpanel::JSON;

use cPstrict;

use constant PROFILE_FILE => q[/var/my.profile];

__PACKAGE__->new()->runtests() unless caller;

my $stage_file;

sub startup : Test(startup) ($self) {

    $self->{mock_cpev} = Test::MockModule->new('cpev');
    $self->{mock_cpev}->redefine(
        ssystem => sub ( $, @cmd ) {
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

sub shutdown : Test( shutdown ) ($self) {

    undef $stage_file;
    delete $self->{mock_profile};

    foreach my $k ( sort keys %$self ) {
        delete $self->{$k};
    }

    return;
}

sub test_backup_and_restore_not_using_ea4 : Test(7) ($self) {

    $self->{mock_httpd}->redefine( is_ea4 => 0 );

    my $ea4 = cpev->new->component('EA4');
    is $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - not using ea4";
    message_seen( 'WARN' => q[Skipping EA4 backup. EA4 does not appear to be enabled on this system] );

    is cpev::read_stage_file(), { ea4 => { enable => 0 } }, "stage file - ea4 is disabled";

    is $ea4->_restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";
    message_seen( 'WARN' => q[Skipping EA4 restore. EA4 does not appear to be enabled on this system.] );

    return;
}

sub test_missing_ea4_profile : Test(6) ($self) {

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        $self->{mock_saferun}->redefine(
            saferunnoerror => sub {
                note "saferunnoerror: no output";
                return;
            },
        );

        my $ea4 = cpev->new->component('EA4');
        like(
            dies { $ea4->_backup_ea4_profile() },
            qr/Unable to backup EA4 profile/,
            "Unable to backup EA4 profile - no profile file"
        );

        _message_run_ea_current_to_profile($os);
    }

    return;
}

sub test_get_ea4_profile : Test(10) ($self) {

    set_os_to('cent');

    my $profile = PROFILE_FILE;
    my $output  = qq[$profile\n];

    $self->{mock_profile}->contents('{}');

    $self->{mock_saferun}->redefine(
        saferunnoerror => sub {
            note "saferunnoerror: ", $output;
            return $output;
        },
    );

    my $ea4 = cpev->new->component('EA4');

    is( $ea4->_get_ea4_profile(), PROFILE_FILE, "_get_ea4_profile" );
    _message_run_ea_current_to_profile( 'cent', 1 );

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

    is( $ea4->_get_ea4_profile(), $f, "_get_ea4_profile with noise..." );

    _message_run_ea_current_to_profile( 'cent', $f );

    return;
}

sub test_get_ea4_profile_check_mode : Test(14) ($self) {

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $output = qq[void\n];

        my $cpev = cpev->new( _is_check_mode => 1 );
        ok -d $cpev->tmp_dir, "tmp_dir works";

        my $mock_b = Test::MockModule->new('Elevate::Blockers')    #
          ->redefine( is_check_mode => 1 );

        ok( Elevate::Blockers->is_check_mode(), 'Elevate::Blockers->is_check_mode()' );

        my $expected_profile = $cpev->tmp_dir() . '/ea_profile.json';
        {
            open( my $fh, '>', $expected_profile ) or die;
            print {$fh} "...\n";
        }

        $self->{mock_saferun}->redefine(
            saferunnoerror => sub {
                note "saferunnoerror: ", $output;
                return $output;
            },
        );

        my $ea4 = $cpev->component('EA4');
        is( $ea4->_get_ea4_profile(), $expected_profile, "_get_ea4_profile uses a temporary file for the profile" );

        my $expected_target = $os eq 'cent' ? 'CentOS_8' : 'CloudLinux_8';
        message_seen( 'INFO' => "Running: /usr/local/bin/ea_current_to_profile --target-os=$expected_target --output=$expected_profile" );
        message_seen( 'INFO' => "Backed up EA4 profile to $expected_profile" );
    }

    return;
}

sub test_tmp_dir : Test(3) ($self) {

    my $cpev = cpev->new();

    my $tmp = $cpev->tmp_dir;
    ok -d $tmp;
    is ref($tmp),      "File::Temp::Dir", "tmp_dir is a File::Temp::Dir object";
    is $cpev->tmp_dir, "$tmp",            "returns the same tmp_dir";

    undef $cpev;

    return;
}

sub backup_non_existing_profile : Test(16) ($self) {

    my $ea4 = cpev->new->component('EA4');

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        like(
            dies { $ea4->_backup_ea4_profile() },
            qr/Unable to backup EA4 profile/,
            "Unable to backup EA4 profile - non existing profile file"
        );

        _message_run_ea_current_to_profile($os);

        $self->{mock_profile}->contents('');

        like(
            dies { $ea4->_backup_ea4_profile() },
            qr/Unable to backup EA4 profile/,
            "Unable to backup EA4 profile - empty profile file"
        );

        _message_run_ea_current_to_profile($os);
    }

    is cpev::read_stage_file(), { ea4 => { enable => 1 } }, "stage file - ea4 is enabled but we failed";
    is $ea4->_restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";

    message_seen( 'WARN' => q[Unable to restore EA4 profile. Is EA4 enabled?] );

    return;
}

sub test_backup_and_restore_ea4_profile : Test(13) ($self) {

    my $ea4 = cpev->new->component('EA4');

    my $profile = { my_profile => ['...'] };

    $self->_update_profile_file($profile);

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        is( $ea4->_backup_ea4_profile(), 1, "backup_ea4_profile - using ea4" );
        _message_run_ea_current_to_profile( $os, 1 );
    }

    is cpev::read_stage_file(), { ea4 => { enable => 1, profile => PROFILE_FILE } }, "stage file - ea4 is enabled / profile is backup";

    is( $ea4->_restore_ea4_profile(), 1, "restore_ea4_profile: profile restored" );
    is $self->{last_ssystem_call}, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it"
      or diag explain $self->{last_ssystem_call};

    return;
}

sub test_backup_and_restore_ea4_profile_dropped_packages : Test(28) ($self) {

    my $ea4 = cpev->new->component('EA4');

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

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

        is $ea4->_backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";
        _message_run_ea_current_to_profile( $os, 1 );

        is cpev::read_stage_file(), {
            ea4 => {
                enable       => 1,                                        #
                profile      => PROFILE_FILE,                             #
                dropped_pkgs => $profile->{os_upgrade}->{dropped_pkgs}    #
            }
          },
          "stage file - ea4 is enabled / profile is backup with dropped_pkgs";

        is $ea4->_restore_ea4_profile(), 1, "restore_ea4_profile: profile restored";
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

        $stage_file->unlink;
    }

    return;
}

sub test_backup_and_restore_ea4_profile_cleanup_dropped_packages : Test(28) ($self) {

    my $ea4 = cpev->new->component('EA4');

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

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

        is $ea4->_backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";
        _message_run_ea_current_to_profile( $os, 1 );

        is cpev::read_stage_file(), {
            ea4 => {
                enable       => 1,                                        #
                profile      => PROFILE_FILE,                             #
                dropped_pkgs => $profile->{os_upgrade}->{dropped_pkgs}    #
            }
          },
          "stage file - ea4 is enabled / profile is backup with dropped_pkgs";

        $profile = {
            "os_upgrade" => {
                "source_os"          => "<the source OS’s display name>",
                "target_os"          => "<the --target-os=value value>",
                "target_obs_project" => "<the target os’s OBS project>",
            }
        };
        $self->_update_profile_file($profile);

        is $ea4->_backup_ea4_profile(), 1, "backup_ea4_profile - using ea4";
        _message_run_ea_current_to_profile( $os, 1 );

        my $stage = cpev::read_stage_file();
        is $stage, {
            ea4 => {
                enable  => 1,               #
                profile => PROFILE_FILE,    #
            }
          },
          "stage file - ea4 is enabled / profile: clear the dropped_pkgs hash"
          or diag explain $stage;

    }

    return;

}

sub test_backup_and_restore_config_files : Test(10) ($self) {
    my $cpev_mock = Test::MockModule->new('cpev');

    $cpev_mock->redefine(
        get_installed_rpms_in_repo => sub { return ( 'ea-foo', 'ea-bar', 'ea-nginx' ) },
        ssystem_capture_output     => sub ( $, @args ) {
            my $pkg         = pop @args;
            my $config_file = $pkg =~ /foo$/ ? '/tmp/foo.conf' : '/tmp/bar.conf';
            my $ret         = {
                status => 0,
                stdout => $pkg eq 'ea-nginx' ? [ '/etc/nginx/conf.d/ea-nginx.conf', '/etc/nginx/nginx.conf' ] : [$config_file],
            };
            return $ret;
        },
    );

    my $ea4 = cpev->new->component('EA4');

    is( $ea4->_backup_config_files(), undef, '_backup_config_files() successfully completes' );

    is(
        cpev::read_stage_file(),
        {
            ea4_config_files => {
                'ea-foo'   => ['/tmp/foo.conf'],
                'ea-bar'   => ['/tmp/bar.conf'],
                'ea-nginx' => [ '/etc/nginx/conf.d/ea-nginx.conf', '/etc/nginx/nginx.conf' ],
            },
        },
        'stage file contains the expected config files',
    );

    my %config_files_restored;
    my $mock_file_copy = Test::MockModule->new('File::Copy');
    $mock_file_copy->redefine(
        move => sub {
            my ( $from, $to ) = @_;
            $config_files_restored{$to} = 1;
            return 1;
        },
    );

    my $mock_foo   = Test::MockFile->file( '/tmp/foo.conf.rpmsave',         '' );
    my $mock_bar   = Test::MockFile->file( '/tmp/bar.conf.rpmsave',         '' );
    my $mock_nginx = Test::MockFile->file( '/etc/nginx/nginx.conf.rpmsave', '' );

    is( $ea4->_restore_config_files(), undef, '_restore_config_files() successfully completes' );

    is(
        \%config_files_restored,
        {
            '/tmp/foo.conf'         => 1,
            '/tmp/bar.conf'         => 1,
            '/etc/nginx/nginx.conf' => 1,
        },
        'The expected files are restored',
    );

    message_seen( INFO => qr/^Restoring config files for package: 'ea-bar'/ );
    message_seen( INFO => qr/^Restoring config files for package: 'ea-foo'/ );
    message_seen( INFO => qr/^Restoring config files for package: 'ea-nginx'/ );

    return;
}

=pod
sub test_blocker_ea4_profile : Test(18) ($self) {

    my $ea4 = cpev->new->component('EA4');

    $self->{mock_cpev}->redefine( backup_ea4_profile => 0 );

    my $ea_info_check = sub {
        message_seen( 'INFO' => "Checking EasyApache profile compatibility with AlmaLinux 8." );
    };

    ok !$cpev->_blocker_ea4_profile(), "no ea4 blockers without an ea4 profile to backup";
    $ea_info_check->();

    $self->{mock_cpev}->redefine( backup_ea4_profile => PROFILE_FILE );

    my $stage_ea4 = {
        profile => '/some/file.not.used.there',
    };
    ok cpev::save_stage_file( { ea4 => $stage_ea4 } ), 'save_stage_file';
    ok !$cpev->_blocker_ea4_profile(),                 "no ea4 blockers: profile without any dropped_pkgs";
    $ea_info_check->();

    $stage_ea4->{'dropped_pkgs'} = {
        "ea-bar" => "exp",
        "ea-baz" => "exp",
    };
    ok cpev::save_stage_file( { ea4 => $stage_ea4 } ), 'save_stage_file';
    ok !$cpev->_blocker_ea4_profile(),                 "no ea4 blockers: profile with dropped_pkgs: exp only";
    $ea_info_check->();

    $stage_ea4->{'dropped_pkgs'} = {
        "pkg1"   => "reg",
        "ea-baz" => "exp",
        "pkg3"   => "reg",
        "pkg4"   => "whatever",
    };
    ok cpev::save_stage_file( { ea4 => $stage_ea4 } ), 'save_stage_file';

    ok my $blocker = $cpev->_blocker_ea4_profile(), "_blocker_ea4_profile ";
    $ea_info_check->();

    message_seen( 'WARN' => qr[Elevation Blocker detected] );

    like $blocker, object {
        prop blessed => 'cpev::Blocker';

        field id => 104;
        field msg => 'One or more EasyApache 4 package(s) are not compatible with AlmaLinux 8.
Please remove these packages before continuing the update.
- pkg1
- pkg3
- pkg4
';

        end();
    }, "blocker with expected error" or diag explain $blocker;

    # make sure to restore context
    $self->{mock_cpev}->unmock('backup_ea4_profile');

    return;
}
=cut

## helpers

sub _message_run_ea_current_to_profile ( $os = 'cent', $success = 0 ) {

    my $target = $os eq 'cent' ? 'CentOS_8' : 'CloudLinux_8';

    message_seen( 'INFO' => qq[Running: /usr/local/bin/ea_current_to_profile --target-os=$target] );
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
