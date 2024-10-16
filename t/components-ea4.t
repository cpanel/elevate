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

    $stage_file = Test::MockFile->file( Elevate::StageFile::ELEVATE_STAGE_FILE() );

    $self->{mock_profile}       = Test::MockFile->file(PROFILE_FILE);
    $self->{mock_imunify_agent} = Test::MockFile->file( Elevate::EA4::IMUNIFY_AGENT() );

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

    my $ea4 = cpev->new->get_component('EA4');

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine(
        _backup_ea_addons => 0,
    );

    is $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - not using ea4";
    message_seen( 'WARN' => q[Skipping EA4 backup. EA4 does not appear to be enabled on this system] );

    is Elevate::StageFile::read_stage_file(), { ea4 => { enable => 0 } }, "stage file - ea4 is disabled";

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

        my $ea4 = cpev->new->get_component('EA4');
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

    my $ea4 = cpev->new->get_component('EA4');

    is( Elevate::EA4::_get_ea4_profile(0), PROFILE_FILE, "_get_ea4_profile" );
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

    is( Elevate::EA4::_get_ea4_profile(0), $f, "_get_ea4_profile with noise..." );

    _message_run_ea_current_to_profile( 'cent', $f );

    return;
}

sub test_get_ea4_profile_check_mode : Test(19) ($self) {

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $output = qq[void\n];

        my $cpev = cpev->new( _is_check_mode => 1 );
        ok -d Elevate::EA4::tmp_dir(), "tmp_dir works";

        my $mock_b = Test::MockModule->new('Elevate::Components')    #
          ->redefine( is_check_mode => 1 );

        ok( Elevate::Components->is_check_mode(), 'Elevate::Components->is_check_mode()' );

        my $expected_profile = Elevate::EA4::tmp_dir() . '/ea_profile.json';
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

        my $ea4 = $cpev->get_component('EA4');
        is( Elevate::EA4::_get_ea4_profile(1), $expected_profile, "_get_ea4_profile uses a temporary file for the profile" );

        my $expected_target = $os eq 'cent' ? 'CentOS_8' : 'CloudLinux_8';
        message_seen( 'INFO' => "Running: /usr/local/bin/ea_current_to_profile --target-os=$expected_target --output=$expected_profile" );
        message_seen( 'INFO' => "Backed up EA4 profile to $expected_profile" );

        # The expected target is CloudLinux_8 when Imunify 360 provides
        # hardened PHP
        if ( $os eq 'cent' ) {
            my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
            $mock_elevate_ea4->redefine(
                _imunify360_is_installed_and_provides_hardened_php => 1,
            );

            is( Elevate::EA4::_get_ea4_profile(1), $expected_profile, "_get_ea4_profile uses a temporary file for the profile" );

            message_seen( 'INFO' => "Running: /usr/local/bin/ea_current_to_profile --target-os=CloudLinux_8 --output=$expected_profile" );
            message_seen( 'INFO' => "Backed up EA4 profile to $expected_profile" );
        }
    }

    return;
}

sub test_tmp_dir : Test(3) ($self) {

    my $cpev = cpev->new();

    my $tmp = Elevate::EA4::tmp_dir();
    ok -d $tmp;
    is ref($tmp),               "File::Temp::Dir", "tmp_dir is a File::Temp::Dir object";
    is Elevate::EA4::tmp_dir(), "$tmp",            "returns the same tmp_dir";

    undef $cpev;

    return;
}

sub backup_non_existing_profile : Test(16) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

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

    is Elevate::StageFile::read_stage_file(), { ea4 => { enable => 1 } }, "stage file - ea4 is enabled but we failed";
    is $ea4->_restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";

    message_seen( 'WARN' => q[Unable to restore EA4 profile. Is EA4 enabled?] );

    return;
}

sub test_backup_and_restore_ea4_profile : Test(13) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my $profile = { my_profile => ['...'] };

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine(
        _backup_ea_addons => 0,
    );

    $self->_update_profile_file($profile);

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        is( $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - using ea4" );
        _message_run_ea_current_to_profile( $os, 1 );
    }

    is Elevate::StageFile::read_stage_file(), { ea4 => { enable => 1, profile => PROFILE_FILE } }, "stage file - ea4 is enabled / profile is backup";

    is( $ea4->_restore_ea4_profile(), 1, "restore_ea4_profile: profile restored" );
    is $self->{last_ssystem_call}, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it"
      or diag explain $self->{last_ssystem_call};

    return;
}

sub test_backup_and_restore_ea4_profile_dropped_packages : Test(28) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

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

        my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
        $mock_elevate_ea4->redefine(
            _backup_ea_addons => 0,
        );

        is $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - using ea4";
        _message_run_ea_current_to_profile( $os, 1 );

        is Elevate::StageFile::read_stage_file(), {
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

    my $ea4 = cpev->new->get_component('EA4');

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

        my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
        $mock_elevate_ea4->redefine(
            _backup_ea_addons => 0,
        );

        is $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - using ea4";
        _message_run_ea_current_to_profile( $os, 1 );

        is Elevate::StageFile::read_stage_file(), {
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

        is $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - using ea4";
        _message_run_ea_current_to_profile( $os, 1 );

        my $stage = Elevate::StageFile::read_stage_file();
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
        ssystem_capture_output => sub ( $, @args ) {
            my $pkg         = pop @args;
            my $config_file = $pkg =~ /foo$/ ? '/tmp/foo.conf' : '/tmp/bar.conf';
            my $ret         = {
                status => 0,
                stdout => $pkg eq 'ea-nginx' ? [ '/etc/nginx/conf.d/ea-nginx.conf', '/etc/nginx/nginx.conf' ] : [$config_file],
            };
            return $ret;
        },
    );

    my $mock_rpm = Test::MockModule->new('Elevate::RPM');
    $mock_rpm->redefine(
        get_installed_rpms => sub {
            return ( 'ea-foo', 'ea-bar', 'ea-nginx', 'not-an-ea-package' );
        },
    );

    my $ea4 = cpev->new->get_component('EA4');

    is( $ea4->_backup_config_files(), undef, '_backup_config_files() successfully completes' );

    is(
        Elevate::StageFile::read_stage_file(),
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
        mv => sub {
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

sub test__ensure_sites_use_correct_php_version : Test(11) ($self) {

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        read_stage_file => [],
    );

    my $result = 1;
    my @saferun_calls;
    my $mock_saferunnoerror = Test::MockModule->new('Cpanel::SafeRun::Simple');
    $mock_saferunnoerror->redefine(
        saferunnoerror => sub {
            my $call_string = join( ' ', @_ );
            push @saferun_calls, $call_string;
            return qq|{"metadata":{"result":$result}}|;
        },
    );

    my $ea4 = cpev->new->get_component('EA4');

    is( $ea4->_ensure_sites_use_correct_php_version, undef, 'Returns undef' );
    is( \@saferun_calls,                             [],    'No API calls are made when no data is present in the stage file' );

    $mock_stagefile->redefine(
        read_stage_file => sub {
            return [
                {
                    version => 'ea-php42',
                    vhost   => 'foo.tld',
                    php_fpm => 0,
                },
                {
                    version => 'ea-php99',
                    vhost   => 'bar.tld',
                    php_fpm => 1,
                },
            ];
        },
    );

    is( $ea4->_ensure_sites_use_correct_php_version, undef, 'Returns undef' );

    is(
        \@saferun_calls,
        [
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php42 vhost=foo.tld php_fpm=0],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php99 vhost=bar.tld php_fpm=1],
        ],
        'The correct API calls are made',
    );

    $result = 0;
    undef @saferun_calls;

    is( $ea4->_ensure_sites_use_correct_php_version, undef, 'Returns undef' );

    is(
        \@saferun_calls,
        [
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php42 vhost=foo.tld php_fpm=0],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php99 vhost=bar.tld php_fpm=1],
        ],
        'The correct API calls are made',
    );

    message_seen( WARN => qr/Unable to set foo\.tld back to its desired PHP version/ );
    message_seen( WARN => qr/Unable to set bar\.tld back to its desired PHP version/ );
    no_messages_seen();

    return;
}

sub test_blocker_ea4_profile : Test(18) ($self) {

    set_os_to('cent');

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine(
        backup => sub { return undef; },
    );

    ok !$ea4->_blocker_ea4_profile(), "no ea4 blockers without an ea4 profile to backup";
    $self->_ea_info_check('AlmaLinux 8');

    $mock_elevate_ea4->redefine(
        _get_ea4_profile => PROFILE_FILE,
    );

    my $stage_ea4 = {
        profile => '/some/file.not.used.there',
    };
    ok Elevate::StageFile::_save_stage_file( { ea4 => $stage_ea4 } ), '_save_stage_file';
    ok !$ea4->_blocker_ea4_profile(),                                 "no ea4 blockers: profile without any dropped_pkgs";
    $self->_ea_info_check('AlmaLinux 8');

    $stage_ea4->{'dropped_pkgs'} = {
        "ea-bar" => "exp",
        "ea-baz" => "exp",
    };
    ok Elevate::StageFile::_save_stage_file( { ea4 => $stage_ea4 } ), '_save_stage_file';
    ok !$ea4->_blocker_ea4_profile(),                                 "no ea4 blockers: profile with dropped_pkgs: exp only";
    $self->_ea_info_check('AlmaLinux 8');

    $stage_ea4->{'dropped_pkgs'} = {
        "pkg1"   => "reg",
        "ea-baz" => "exp",
        "pkg3"   => "reg",
        "pkg4"   => "whatever",
    };
    ok Elevate::StageFile::_save_stage_file( { ea4 => $stage_ea4 } ), '_save_stage_file';

    ok my $blocker = $ea4->_blocker_ea4_profile(), "_blocker_ea4_profile ";
    $self->_ea_info_check('AlmaLinux 8');

    message_seen( 'WARN' => qr[Elevation Blocker detected] );

    like $blocker, object {
        prop blessed => 'cpev::Blocker';

        field id => 'Elevate::Components::EA4::_blocker_ea4_profile';
        field msg => 'One or more EasyApache 4 package(s) are not compatible with AlmaLinux 8.
Please remove these packages before continuing the update.
- pkg1
- pkg3
- pkg4
';

        end();
    }, "blocker with expected error" or diag explain $blocker;

    return;
}

sub test_blocker_incompatible_package : Test(11) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_isea4 = Test::MockFile->file( '/etc/cpanel/ea4/is_ea4' => 1 );
    my $type       = '';

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine( backup => sub { return; } );
    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        _read_stage_file => sub {
            return {
                ea4 => {
                    dropped_pkgs => {
                        'ea4-bad-pkg' => $type,
                    },
                },
            };
        }
    );

    # only testing the blocking case

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $expected_target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';
        like(
            $ea4->_blocker_ea4_profile(),
            {
                id  => q[Elevate::Components::EA4::_blocker_ea4_profile],
                msg => <<~"EOS",
        One or more EasyApache 4 package(s) are not compatible with $expected_target_os.
        Please remove these packages before continuing the update.
        - ea4-bad-pkg
        EOS

            },
            'blocks when EA4 has an incompatible package'
        );

        my $target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';
        $self->_ea_info_check($target_os);
        message_seen( WARN => <<"EOS");
*** Elevation Blocker detected: ***
One or more EasyApache 4 package(s) are not compatible with $target_os.
Please remove these packages before continuing the update.
- ea4-bad-pkg

EOS

    }

    no_messages_seen();
    return;
}

sub test_blocker_behavior : Test(49) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_ea4 = Test::MockModule->new('Elevate::Components::EA4');

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine( backup => sub { return; } );

    for my $os ( 'cent', 'cloud' ) {
        set_os_to($os);

        my $target_os = $os eq 'cent' ? 'AlmaLinux 8' : 'CloudLinux 8';

        ok !$ea4->_blocker_ea4_profile(), "no ea4 blockers without an ea4 profile to backup";
        $self->_ea_info_check($target_os);

        my $stage_ea4 = {
            profile => '/some/file.not.used.there',
        };

        my $update_stage_file_data = {};

        my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
        $mock_stagefile->redefine(
            _read_stage_file => sub {
                return { ea4 => $stage_ea4 };
            },
            update_stage_file => sub ($data) {
                $update_stage_file_data = $data;
            },
            remove_from_stage_file => 1,
        );

        ok( !$ea4->_blocker_ea4_profile(), "no ea4 blockers: profile without any dropped_pkgs" );

        $self->_ea_info_check($target_os);

        $stage_ea4->{'dropped_pkgs'} = {
            "ea-bar" => "exp",
            "ea-baz" => "exp",
        };
        ok( !$ea4->_blocker_ea4_profile(), "no ea4 blockers: profile with dropped_pkgs: exp only" );
        $self->_ea_info_check($target_os);

        $stage_ea4->{'dropped_pkgs'} = {
            "pkg1"   => "reg",
            "ea-baz" => "exp",
            "pkg3"   => "reg",
            "pkg4"   => "whatever",
        };

        ok my $blocker = $ea4->_blocker_ea4_profile(), "_blocker_ea4_profile ";
        $self->_ea_info_check($target_os);

        message_seen( 'WARN' => qr[Elevation Blocker detected] );

        like $blocker, object {
            prop blessed => 'cpev::Blocker';

            field id => q[Elevate::Components::EA4::_blocker_ea4_profile];
            field msg => qq[One or more EasyApache 4 package(s) are not compatible with $target_os.
Please remove these packages before continuing the update.
- pkg1
- pkg3
- pkg4
];

            end();
        }, "blocker with expected error" or diag explain $blocker;

        $mock_ea4->redefine(
            _php_version_is_in_use => 1,
        );

        $stage_ea4->{'dropped_pkgs'} = {
            pkg1       => 'exp',
            pkg2       => 'reg',
            'ea-php42' => 'reg',
        };

        ok $blocker = $ea4->_blocker_ea4_profile(), "_blocker_ea4_profile ";
        $self->_ea_info_check($target_os);

        message_seen( 'WARN' => qr[Elevation Blocker detected] );

        like $blocker, object {
            prop blessed => 'cpev::Blocker';

            field id => q[Elevate::Components::EA4::_blocker_ea4_profile];
            field msg => qq[One or more EasyApache 4 package(s) are not compatible with $target_os.
Please remove these packages before continuing the update.
- ea-php42
- pkg2
];

            end();
        }, "blocker with expected error when dropped ea-php package is in use"
          or diag explain $blocker;

        $mock_ea4->redefine(
            _php_version_is_in_use => 0,
        );

        $stage_ea4->{'dropped_pkgs'} = {
            'ea-php42' => 'reg',
        };

        ok !$ea4->_blocker_ea4_profile(), 'No blocker when dropped package is an ea-php version that is not in use';
        $self->_ea_info_check($target_os);

        $stage_ea4 = {};
    }

    no_messages_seen();
    return;
}

sub test__php_version_is_in_use : Test(3) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_ea4 = Test::MockModule->new('Elevate::Components::EA4');

    $mock_ea4->redefine(
        _get_php_usage => sub ($self) {
            return {
                api_fail => 1,
            };
        },
    );

    is( $ea4->_php_version_is_in_use('ea-php42'), 1, 'The version is always considered to be in use when the underlying API call fails' );

    my $is_installed = 1;
    $mock_ea4->redefine(
        _get_php_usage => sub ($self) {
            return {
                'ea-php42' => $is_installed,
            };
        },
    );

    is( $ea4->_php_version_is_in_use('ea-php42'), 1, 'Returns 1 when the version of PHP is in use' );

    $is_installed = 0;

    is( $ea4->_php_version_is_in_use('ea-php42'), 0, 'Returns 0 when the version of PHP is NOT in use' );

    return;
}

sub test__get_php_versions_in_use : Test(7) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_result = 'nope';
    my @saferun_calls;
    my $mock_saferunnoerror = Test::MockModule->new('Cpanel::SafeRun::Simple');
    $mock_saferunnoerror->redefine(
        saferunnoerror => sub {
            @saferun_calls = @_;
            return $mock_result;
        },
    );

    my $mock_stagefile = Test::MockModule->new('Elevate::StageFile');
    $mock_stagefile->redefine(
        update_stage_file      => 1,
        remove_from_stage_file => 1,
    );

    is( $ea4->_get_php_usage(), { api_fail => 1, }, 'api_fail is set when the API call does not return valid JSON' );

    is( \@saferun_calls, [qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_vhost_versions}], 'The expected API call is made' );

    message_seen( WARN => qr/The php_get_vhost_versions API call failed/ );

    $ea4->_get_php_usage();
    is( \@saferun_calls, [qw{/usr/local/cpanel/bin/whmapi1 --output=json php_get_vhost_versions}], 'The API call is only made one time' );

    local $Elevate::Components::EA4::php_usage = undef;
    $mock_result = {
        metadata => {
            result => 1,
        },
        data => {
            versions => [
                {
                    version => 'ea-php1',
                },
                {
                    version => 'ea-php2',
                },
                {
                    version => 'ea-php3',
                },
            ],
        },
    };

    $mock_result = Cpanel::JSON::Dump($mock_result);

    is(
        $ea4->_get_php_usage(),
        {
            'ea-php1' => 1,
            'ea-php2' => 1,
            'ea-php3' => 1,
        },
        'The expected result is returned when the API call succeeds',
    );

    no_messages_seen();
    return;
}

=pod

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

sub _ea_info_check ( $self, $os ) {
    message_seen( 'INFO' => "Checking EasyApache profile compatibility with $os." );
    return;
}

1;
