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

sub test_missing_ea4_profile : Test(15) ($self) {

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

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

            _message_run_ea_current_to_profile();
        }
    }

    return;
}

sub test_get_ea4_profile : Test(10) ($self) {

    set_os_to( 'cent', 7 );

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

    is( Elevate::EA4::_get_ea4_profile(0), $f, "_get_ea4_profile with noise..." );

    _message_run_ea_current_to_profile($f);

    return;
}

sub test_get_ea4_profile_check_mode : Test(45) ($self) {

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

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

            my $expected_target;
            if ( $distro eq 'cent' && $version == 7 ) {
                $expected_target = 'CentOS_8';
            }
            elsif ( $distro eq 'cloud' && $version == 7 ) {
                $expected_target = 'CloudLinux_8';
            }
            elsif ( $distro eq 'cloud' && $version == 8 ) {
                $expected_target = 'CloudLinux_9';
            }
            elsif ( $distro eq 'alma' && $version == 8 ) {
                $expected_target = 'CentOS_9';
            }
            elsif ( $distro eq 'ubuntu' && $version == 20 ) {
                $expected_target = 'Ubuntu_22.04';
            }
            else {
                die "Unknown distro and version combination: $distro $version\n";
            }

            message_seen( 'INFO' => "Running: /usr/local/bin/ea_current_to_profile --target-os=$expected_target --output=$expected_profile" );
            message_seen( 'INFO' => "Backed up EA4 profile to $expected_profile" );

            # The expected target is CloudLinux_8 when Imunify 360 provides
            # hardened PHP
            if ( ( $distro eq 'cent' && $version == 7 ) || ( $distro eq 'alma' && $version == 8 ) ) {
                my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
                $mock_elevate_ea4->redefine(
                    _imunify360_is_installed_and_provides_hardened_php => 1,
                );

                is( Elevate::EA4::_get_ea4_profile(1), $expected_profile, "_get_ea4_profile uses a temporary file for the profile" );

                my $expected_target = $distro eq 'cent' && $version == 7 ? 'CloudLinux_8' : 'CloudLinux_9';
                message_seen( 'INFO' => "Running: /usr/local/bin/ea_current_to_profile --target-os=$expected_target --output=$expected_profile" );
                message_seen( 'INFO' => "Backed up EA4 profile to $expected_profile" );
            }
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

sub backup_non_existing_profile : Test(34) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my $mock_ea4_install = Test::MockModule->new('Cpanel::EA4::Install');
    $mock_ea4_install->redefine(
        install_ea4_repo => 1,
    );

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            like(
                dies { $ea4->_backup_ea4_profile() },
                qr/Unable to backup EA4 profile/,
                "Unable to backup EA4 profile - non existing profile file"
            );

            _message_run_ea_current_to_profile();

            $self->{mock_profile}->contents('');

            like(
                dies { $ea4->_backup_ea4_profile() },
                qr/Unable to backup EA4 profile/,
                "Unable to backup EA4 profile - empty profile file"
            );

            _message_run_ea_current_to_profile();
        }
    }

    is Elevate::StageFile::read_stage_file(), { ea4 => { enable => 1 } }, "stage file - ea4 is enabled but we failed";
    is $ea4->_restore_ea4_profile(), undef, "restore_ea4_profile: nothing to restore";

    message_seen( 'WARN' => q[Unable to restore EA4 profile. Is EA4 enabled?] );

    return;
}

sub test_backup_and_restore_ea4_profile : Test(28) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my $mock_ea4_install = Test::MockModule->new('Cpanel::EA4::Install');
    $mock_ea4_install->redefine(
        install_ea4_repo => 1,
    );

    my $profile = { my_profile => ['...'] };

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine(
        _backup_ea_addons => 0,
    );

    $self->_update_profile_file($profile);

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            is( $ea4->_backup_ea4_profile(), undef, "backup_ea4_profile - using ea4" );
            _message_run_ea_current_to_profile(1);
        }
    }

    is Elevate::StageFile::read_stage_file(), { ea4 => { enable => 1, profile => PROFILE_FILE } }, "stage file - ea4 is enabled / profile is backup";

    is( $ea4->_restore_ea4_profile(), 1, "restore_ea4_profile: profile restored" );
    is $self->{last_ssystem_call}, [qw{ /usr/local/bin/ea_install_profile --install /var/my.profile}], "call ea_install_profile to restore it"
      or diag explain $self->{last_ssystem_call};

    return;
}

sub test_backup_and_restore_ea4_profile_dropped_packages : Test(70) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my $mock_ea4_install = Test::MockModule->new('Cpanel::EA4::Install');
    $mock_ea4_install->redefine(
        install_ea4_repo => 1,
    );

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

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
            _message_run_ea_current_to_profile(1);

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
    }

    return;
}

sub test_backup_and_restore_ea4_profile_cleanup_dropped_packages : Test(60) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

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
            _message_run_ea_current_to_profile(1);

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
            _message_run_ea_current_to_profile(1);

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
    }

    return;

}

sub test_backup_and_restore_config_files : Test(60) ($self) {
    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( sort keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my %config_files_restored;
            my $mock_file_copy = Test::MockModule->new('File::Copy');
            $mock_file_copy->redefine(
                cp => 1,
                mv => sub {
                    my ( $from, $to ) = @_;
                    $config_files_restored{$to} = 1;
                    return 1;
                },
            );

            my $mock_pkgmgr = Test::MockModule->new( ref Elevate::PkgMgr::instance() );
            $mock_pkgmgr->redefine(
                ssystem_capture_output => sub ( $, @args ) {
                    my $pkg = pop @args;

                    my $config_file;
                    $config_file = '/tmp/foo.conf'      if $pkg =~ /foo$/;
                    $config_file = '/tmp/bar.conf'      if $pkg =~ /bar$/;
                    $config_file = '/tmp/altcloud.conf' if $pkg =~ /cloud$/;

                    my $ret = {
                        status => 0,
                        stdout => $pkg eq 'ea-nginx' ? [ '/etc/nginx/conf.d/ea-nginx.conf', '/etc/nginx/nginx.conf' ] : [$config_file],
                    };

                    return $ret;
                },
                get_installed_pkgs => sub {
                    return {
                        'ea-foo'    => 1,
                        'ea-bar'    => 1,
                        'ea-nginx'  => 1,
                        'alt-cloud' => 1,
                    };
                },
            );

            my $ea4 = cpev->new->get_component('EA4');

            is( $ea4->_backup_config_files(), undef, '_backup_config_files() successfully completes' );

            is(
                Elevate::StageFile::read_stage_file(),
                {
                    ea4_config_files => {
                        'ea-foo'    => ['/tmp/foo.conf'],
                        'ea-bar'    => ['/tmp/bar.conf'],
                        'ea-nginx'  => [ '/etc/nginx/conf.d/ea-nginx.conf', '/etc/nginx/nginx.conf' ],
                        'alt-cloud' => ['/tmp/altcloud.conf'],
                    },
                },
                'stage file contains the expected config files',
            );

            my $mock_foo      = Test::MockFile->file( '/tmp/foo.conf.rpmsave',         '' );
            my $mock_bar      = Test::MockFile->file( '/tmp/bar.conf.rpmsave',         '' );
            my $mock_nginx    = Test::MockFile->file( '/etc/nginx/nginx.conf.rpmsave', '' );
            my $mock_altcloud = Test::MockFile->file( '/tmp/altcloud.conf.rpmsave',    '' );

            is( $ea4->_restore_config_files(), undef, '_restore_config_files() successfully completes' );

            is(
                \%config_files_restored,
                {
                    '/tmp/foo.conf'         => 1,
                    '/tmp/bar.conf'         => 1,
                    '/etc/nginx/nginx.conf' => 1,
                    '/tmp/altcloud.conf'    => 1,
                },
                'The expected files are restored',
            );

            message_seen( INFO => qr/^Restoring config files for package: 'alt-cloud'/ );
            message_seen( INFO => qr/^Restoring config files for package: 'ea-bar'/ );
            message_seen( INFO => qr/^Restoring config files for package: 'ea-foo'/ );
            message_seen( INFO => qr/^Restoring config files for package: 'ea-nginx'/ );
        }
    }

    return;
}

sub test_restore_ea_prefix_packages : Test(15) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my %installed;
    my @install_calls;

    my $mock_pkgmgr = Test::MockModule->new('Elevate::PkgMgr');
    $mock_pkgmgr->redefine(
        get_installed_pkgs => sub (@filter) {
            return { map { $_ => 1 } keys %installed };
        },
        install_with_options => sub ( $options, $pkgs ) {
            push @install_calls, { options => $options, pkgs => $pkgs };
            $installed{$_} = 1 for @$pkgs;    # simulate a fully successful reinstall
            return;
        },
    );

    my @notifications;
    my $mock_notify = Test::MockModule->new('Elevate::Notify');
    $mock_notify->redefine( add_final_notification => sub ( $msg, $warn = 0 ) { push @notifications, $msg; return 1; } );

    # No snapshot recorded: nothing to do.
    $stage_file->unlink;
    is $ea4->_restore_ea_prefix_packages(), undef, 'no-op when no ea-prefix snapshot was recorded';
    is \@install_calls,                     [],    'no reinstall attempted without a snapshot';

    # Every snapshotted package is already installed: nothing to do.
    %installed = ( 'ea-apache24' => 1, 'ea-php83' => 1 );
    $stage_file->unlink;
    Elevate::StageFile::update_stage_file( { ea_prefix_packages_to_restore => [ 'ea-apache24', 'ea-php83' ] } );
    is $ea4->_restore_ea_prefix_packages(), undef, 'no-op when every snapshot package is already installed';
    is \@install_calls,                     [],    'no reinstall when nothing is missing';
    is \@notifications,                     [],    'no notification when nothing is missing';

    # A package is missing and the reinstall restores it: install runs, no notification.
    %installed     = ( 'ea-apache24' => 1 );
    @install_calls = ();
    @notifications = ();
    $stage_file->unlink;
    Elevate::StageFile::update_stage_file( { ea_prefix_packages_to_restore => [ 'ea-apache24', 'ea-php83' ] } );
    is $ea4->_restore_ea_prefix_packages(), undef,                                                      'completes when the reinstall restores the missing package';
    is \@install_calls,                     [ { options => ['--skip-broken'], pkgs => ['ea-php83'] } ], 'reinstalls only the missing package with --skip-broken';
    message_seen( INFO => qr/Reinstalling 1 ea-prefix package/ );
    is \@notifications, [], 'no notification when the reinstall succeeds';

    # A package cannot be reinstalled: surface a final notification naming it.
    %installed     = ( 'ea-apache24' => 1 );
    @install_calls = ();
    @notifications = ();
    $mock_pkgmgr->redefine(
        install_with_options => sub ( $options, $pkgs ) {
            $installed{$_} = 1 for grep { $_ ne 'ea-nodejs10' } @$pkgs;    # ea-nodejs10 stays broken
            return;
        },
    );
    $stage_file->unlink;
    Elevate::StageFile::update_stage_file( { ea_prefix_packages_to_restore => [ 'ea-apache24', 'ea-php83', 'ea-nodejs10' ] } );
    is $ea4->_restore_ea_prefix_packages(), undef, 'completes when a package cannot be restored';
    message_seen( INFO => qr/Reinstalling 2 ea-prefix package/ );
    is scalar(@notifications), 1, 'final notification surfaced when a package cannot be reinstalled';
    like $notifications[0], qr/ea-nodejs10/, 'notification names the package that could not be reinstalled';

    return;
}

sub test_restore_ea4_profile_backstops_on_failure : Test(4) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my $mock_ea4_install = Test::MockModule->new('Cpanel::EA4::Install');
    $mock_ea4_install->redefine( install_ea4_repo => 1 );

    # Enable EA4 and point at a profile that exists.
    $self->_update_profile_file( { my_profile => ['...'] } );
    Elevate::StageFile::update_stage_file( { ea4 => { enable => 1, profile => PROFILE_FILE } } );

    my $backstop_called = 0;
    my $mock_ea4        = Test::MockModule->new('Elevate::Components::EA4');
    $mock_ea4->redefine( _restore_ea_prefix_packages => sub { $backstop_called++; return; } );

    # Control the exit status of the ea_install_profile call.
    my $exit      = 0;
    my $mock_cpev = Test::MockModule->new('cpev');
    $mock_cpev->redefine( ssystem => sub ( $, @cmd ) { return $exit; } );

    $exit            = 0;
    $backstop_called = 0;
    is $ea4->_restore_ea4_profile(), 1, 'restore_ea4_profile completes on a clean ea_install_profile exit';
    is $backstop_called,             0, 'backstop is not invoked when ea_install_profile exits cleanly';

    $exit            = 1;
    $backstop_called = 0;
    is $ea4->_restore_ea4_profile(), 1, 'restore_ea4_profile completes after a failed ea_install_profile exit';
    is $backstop_called,             1, 'backstop is invoked when ea_install_profile exits non-zero';

    return;
}

sub test__ensure_sites_use_correct_php_version : Test(17) ($self) {

    my $mock_touchfile = Test::MockFile->file('/var/cpanel/elevate_skip_preserve_php_versions');

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
            my ($desired_key) = @_;

            if ( $desired_key eq 'php_get_system_default_version' ) {
                return 'ea-php23';
            }
            elsif ( $desired_key eq 'php_get_inherited_domains' ) {
                return ['finn.tld'];
            }
            elsif ( $desired_key eq 'php_get_vhost_versions' ) {
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
                    {
                        version => 'ea-php23',
                        vhost   => 'finn.tld',
                        php_fpm => 0,
                    },
                ];
            }
        },
    );

    $mock_touchfile->touch();

    is( $ea4->_ensure_sites_use_correct_php_version, undef, 'Returns undef' );
    is( \@saferun_calls,                             [],    'No API calls are made when the touch file is in place' );

    undef @saferun_calls;
    unlink '/var/cpanel/elevate_skip_preserve_php_versions';

    is( $ea4->_ensure_sites_use_correct_php_version, undef, 'Returns undef' );

    is(
        \@saferun_calls,
        [
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_system_default_version version=ea-php23],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php42 vhost=foo.tld php_fpm=0],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php99 vhost=bar.tld php_fpm=1],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=inherit vhost=finn.tld php_fpm=0],
        ],
        'The correct API calls are made',
    );

    $result = 0;
    undef @saferun_calls;

    is( $ea4->_ensure_sites_use_correct_php_version, undef, 'Returns undef' );

    is(
        \@saferun_calls,
        [
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_system_default_version version=ea-php23],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php42 vhost=foo.tld php_fpm=0],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=ea-php99 vhost=bar.tld php_fpm=1],
            q[/usr/local/cpanel/bin/whmapi1 --output=json php_set_vhost_versions version=inherit vhost=finn.tld php_fpm=0],
        ],
        'The correct API calls are made',
    );

    message_seen( WARN => qr/Unable to set the default PHP version back to its original version/ );
    message_seen( WARN => qr/Unable to set foo\.tld back to its desired PHP version/ );
    message_seen( WARN => qr/Unable to set bar\.tld back to its desired PHP version/ );
    message_seen( WARN => qr/Unable to set finn\.tld back to its desired PHP version/ );
    no_messages_seen();

    return;
}

sub test__snapshot_user_php_selectors : Test(8) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my @cpusers  = qw( alice bob carol dave );
    my %homedirs = (
        alice => '/home/alice',
        bob   => '/home/bob',
        carol => '/home/carol',
        dave  => '/home/dave',
    );

    my $mock_users = Test::MockModule->new('Cpanel::Config::Users');
    $mock_users->redefine( getcpusers => sub { return @cpusers; } );

    my $mock_pwcache = Test::MockModule->new('Cpanel::PwCache');
    $mock_pwcache->redefine( gethomedir => sub ($user) { return $homedirs{$user}; } );

    # 1. cloudlinux-selector is not present/executable -> noop
    my $mock_cli = Test::MockFile->file('/usr/sbin/cloudlinux-selector');    # missing
    is( $ea4->_snapshot_user_php_selectors,                        undef, 'noop when cloudlinux-selector is not present' );
    is( Elevate::StageFile::read_stage_file('user_php_selectors'), {},    'stage file untouched when the selector binary is absent' );

    # Make the binary executable for the remaining scenarios.
    $mock_cli->contents('');
    $mock_cli->chmod(0755);

    # 2. Every user is on the native version -> noop
    my $mock_alice = Test::MockFile->file( '/home/alice/.cl.selector/defaults.cfg', "[versions]\nphp = native\n" );
    my $mock_bob   = Test::MockFile->file( '/home/bob/.cl.selector/defaults.cfg',   "[versions]\nphp = native\n" );
    my $mock_carol = Test::MockFile->file('/home/carol/.cl.selector/defaults.cfg');                                  # missing file is skipped
    my $mock_dave  = Test::MockFile->file( '/home/dave/.cl.selector/defaults.cfg', "[versions]\nphp = native\n" );

    is( $ea4->_snapshot_user_php_selectors,                        undef, 'noop when no user has a non-native PHP Selector version' );
    is( Elevate::StageFile::read_stage_file('user_php_selectors'), {},    'stage file untouched when every user is native' );

    # 3. Some users are on a non-native version -> recorded
    $mock_alice->contents("[versions]\nphp = 7.4\n");

    # The php setting outside of the [versions] section must be ignored.
    $mock_dave->contents("[other]\nphp = 9.9\n[versions]\nphp = 8.1\n");

    is( $ea4->_snapshot_user_php_selectors, undef, 'returns undef on success' );
    message_seen( INFO => 'Recorded 2 user(s) with non-native PHP Selector versions.' );

    is(
        Elevate::StageFile::read_stage_file('user_php_selectors'),
        { alice => '7.4', dave => '8.1' },
        'Only non-native versions from the [versions] section are recorded',
    );

    return;
}

sub test__snapshot_php_fpm_services : Test(6) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my $output = '';
    $self->{mock_saferun}->redefine( saferunnoerror => sub (@cmd) { return $output; } );

    # 1. Nothing is enabled -> noop
    $output = <<~'EOS';
    alt-php74-fpm.service       disabled  disabled
    ea-php80-php-fpm.service    masked    disabled
    EOS

    is( $ea4->_snapshot_php_fpm_services,                                undef, 'noop when no PHP-FPM service is enabled' );
    is( Elevate::StageFile::read_stage_file('php_fpm_services_enabled'), {},    'stage file untouched when nothing is enabled' );

    # 2. Some services are enabled -> recorded, sorted
    $output = <<~'EOS';
    ea-php80-php-fpm.service    enabled   enabled
    alt-php74-fpm.service       enabled   enabled
    alt-php73-fpm.service       disabled  disabled
    EOS

    is( $ea4->_snapshot_php_fpm_services, undef, 'returns undef on success' );
    message_seen( INFO => 'Recorded 2 PHP-FPM service(s) currently enabled.' );

    is(
        Elevate::StageFile::read_stage_file('php_fpm_services_enabled'),
        [ 'alt-php74-fpm.service', 'ea-php80-php-fpm.service' ],
        'Only enabled services are recorded, sorted',
    );

    return;
}

sub test__restore_user_php_selectors : Test(22) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my @sro_calls;
    my %sro_should_fail;
    my $mock_sro = Test::MockModule->new('Cpanel::SafeRun::Object');
    $mock_sro->redefine(
        new => sub ( $class, %args ) {
            push @sro_calls, { program => $args{program}, args => $args{args} };
            return bless { args => $args{args} }, $class;
        },
        CHILD_ERROR => sub ($self) {
            for my $arg ( @{ $self->{args} } ) {
                return 1 if $sro_should_fail{$arg};
            }
            return 0;
        },
        autopsy => sub ($self) { return 'mocked autopsy'; },
    );

    my @notifications;
    my $mock_notify = Test::MockModule->new('Elevate::Notify');
    $mock_notify->redefine( add_final_notification => sub ( $msg, $warn_now = 0 ) { push @notifications, $msg; return 1; } );

    # 1. Nothing in the stage file -> noop
    is( $ea4->_restore_user_php_selectors, undef, 'noop when the stage file has no PHP Selector data' );
    is( \@sro_calls,                       [],    'no cloudlinux-selector calls when there is nothing to restore' );

    Elevate::StageFile::update_stage_file( { user_php_selectors => { alice => '7.4', bob => '8.1' } } );

    # 2. cloudlinux-selector is not executable on the target -> all fail
    my $mock_cli = Test::MockFile->file('/usr/sbin/cloudlinux-selector');    # missing
    is( $ea4->_restore_user_php_selectors, undef, 'returns undef when the selector binary is absent' );
    is( \@sro_calls,                       [],    'no calls attempted when the selector binary is absent' );
    message_seen( WARN => 'Cannot restore PHP Selector versions: /usr/sbin/cloudlinux-selector is not executable on the target OS.' );
    message_seen( WARN => qr/Failed to restore PHP Selector versions/ );
    is( scalar @notifications, 1, 'a final notification is queued when restore is impossible' );

    # 3. Executable, all users restore cleanly
    @notifications = ();
    $mock_cli->contents('');
    $mock_cli->chmod(0755);

    is( $ea4->_restore_user_php_selectors, undef, 'returns undef on success' );
    message_seen( INFO => 'Restoring PHP Selector versions for 2 user(s).' );

    is(
        \@sro_calls,
        [
            { program => '/usr/sbin/cloudlinux-selector', args => [qw(set --json --interpreter=php --current-version=7.4 --user=alice)] },
            { program => '/usr/sbin/cloudlinux-selector', args => [qw(set --json --interpreter=php --current-version=8.1 --user=bob)] },
        ],
        'cloudlinux-selector is invoked once per user, sorted by user',
    );
    is( \@notifications, [], 'no notification queued when every user restores cleanly' );

    # 4. Executable, one user fails
    @sro_calls       = ();
    @notifications   = ();
    %sro_should_fail = ( '--user=bob' => 1 );

    is( $ea4->_restore_user_php_selectors, undef, 'returns undef when a user fails to restore' );
    message_seen( INFO => 'Restoring PHP Selector versions for 2 user(s).' );
    message_seen( WARN => 'Could not restore user bob: mocked autopsy' );
    message_seen( WARN => qr/Failed to restore PHP Selector versions/ );
    is( scalar @notifications, 1, 'a final notification is queued for the failed user' );

    return;
}

sub test__restore_php_fpm_services : Test(15) ($self) {

    my $ea4 = cpev->new->get_component('EA4');

    my @sro_calls;
    my %sro_should_fail;
    my $mock_sro = Test::MockModule->new('Cpanel::SafeRun::Object');
    $mock_sro->redefine(
        new => sub ( $class, %args ) {
            push @sro_calls, { program => $args{program}, args => $args{args} };
            return bless { args => $args{args} }, $class;
        },
        CHILD_ERROR => sub ($self) {
            for my $arg ( @{ $self->{args} } ) {
                return 1 if $sro_should_fail{$arg};
            }
            return 0;
        },
        autopsy => sub ($self) { return 'mocked autopsy'; },
    );

    my @notifications;
    my $mock_notify = Test::MockModule->new('Elevate::Notify');
    $mock_notify->redefine( add_final_notification => sub ( $msg, $warn_now = 0 ) { push @notifications, $msg; return 1; } );

    # 1. Nothing in the stage file -> noop
    is( $ea4->_restore_php_fpm_services, undef, 'noop when the stage file has no PHP-FPM data' );
    is( \@sro_calls,                     [],    'no systemctl calls when there is nothing to restore' );

    Elevate::StageFile::update_stage_file( { php_fpm_services_enabled => [qw(alt-php74-fpm.service ea-php80-php-fpm.service)] } );

    # 2. All units re-enable cleanly
    is( $ea4->_restore_php_fpm_services, undef, 'returns undef on success' );
    message_seen( INFO => 'Re-enabling 2 PHP-FPM service(s).' );

    is(
        \@sro_calls,
        [
            { program => '/usr/bin/systemctl', args => [qw(enable alt-php74-fpm.service)] },
            { program => '/usr/bin/systemctl', args => [qw(enable ea-php80-php-fpm.service)] },
        ],
        'systemctl enable is invoked once per unit',
    );
    is( \@notifications, [], 'no notification queued when every service re-enables cleanly' );

    # 3. One unit fails to re-enable
    @sro_calls       = ();
    @notifications   = ();
    %sro_should_fail = ( 'ea-php80-php-fpm.service' => 1 );

    is( $ea4->_restore_php_fpm_services, undef, 'returns undef when a unit fails to re-enable' );
    message_seen( INFO => 'Re-enabling 2 PHP-FPM service(s).' );
    message_seen( WARN => 'Could not re-enable ea-php80-php-fpm.service: mocked autopsy' );
    message_seen( WARN => qr/Failed to re-enable PHP-FPM services/ );
    is( scalar @notifications, 1, 'a final notification is queued for the failed unit' );

    return;
}

sub test_blocker_ea4_profile : Test(18) ($self) {

    set_os_to( 'cent', 7 );

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

    message_seen( 'ERROR' => qr[Elevation Blocker detected] );

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

sub test_blocker_incompatible_package : Test(26) ($self) {

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

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $expected_target_os = Elevate::OS::upgrade_to_pretty_name();
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

            $self->_ea_info_check($expected_target_os);
            message_seen( ERROR => <<"EOS" );
*** Elevation Blocker detected: ***
One or more EasyApache 4 package(s) are not compatible with $expected_target_os.
Please remove these packages before continuing the update.
- ea4-bad-pkg

EOS

        }
    }

    no_messages_seen();
    return;
}

sub test_blocker_behavior : Test(121) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_ea4 = Test::MockModule->new('Elevate::Components::EA4');

    my $mock_elevate_ea4 = Test::MockModule->new('Elevate::EA4');
    $mock_elevate_ea4->redefine( backup => sub { return; } );

    my %os_hash = $self->_get_os_hash();
    foreach my $distro ( keys %os_hash ) {
        foreach my $version ( @{ $os_hash{$distro} } ) {
            set_os_to( $distro, $version );

            my $target_os = Elevate::OS::upgrade_to_pretty_name();

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

            message_seen( 'ERROR' => qr[Elevation Blocker detected] );

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

            message_seen( 'ERROR' => qr[Elevation Blocker detected] );

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

sub test__get_installed_non_ea_prefix_supported_packages : Test(4) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_path_tiny = Test::MockModule->new('Path::Tiny');
    $mock_path_tiny->redefine(
        path => sub { die "do not call this yet\n"; },
    );

    local $Cpanel::PackMan::VERSION = 0.02;

    is(
        $ea4->_get_installed_non_ea_prefix_supported_packages,
        undef,
        'Returns undef when Cpanel::PackMan version does not support alt prefixes',
    );

    local $Cpanel::PackMan::VERSION = 0.03;

    $mock_path_tiny->redefine(
        path => sub {
            my ($dir) = @_;
            my $self = [
                $dir,
            ];
            return bless $self, 'Path::Tiny';
        },
        children => sub {
            my ($self) = @_;
            return $self;
        },
        basename => sub { return; },
    );

    my $mock_packman = Test::MockModule->new('Cpanel::PackMan');
    $mock_packman->redefine(
        instance => sub { die "do not call this yet\n"; },
    );

    is(
        $ea4->_get_installed_non_ea_prefix_supported_packages,
        undef,
        'Returns undef when the additional prefix dir does not exist / have files in it',
    );

    $mock_path_tiny->redefine(
        basename => sub { return 'alt'; },
    );

    $mock_packman->redefine(
        instance => sub {
            my ($class) = @_;
            return bless {}, $class;
        },
        list => sub {
            return (
                'alt-php1',
                'alt-php2',
                'alt-php42',
            );
        },
    );

    my $mock_elevate_pkgmgr = Test::MockModule->new('Elevate::PkgMgr');
    $mock_elevate_pkgmgr->redefine(
        get_installed_pkgs => sub {
            return {
                'alt-php42' => 1,
            };
        },
    );

    my @pkgs = $ea4->_get_installed_non_ea_prefix_supported_packages;
    is(
        \@pkgs,
        ['alt-php42'],
        'Returns the installed alt prefix package',
    );

    @pkgs = undef;

    $mock_path_tiny->redefine(
        path => sub { die "should be cached\n"; },
    );

    @pkgs = $ea4->_get_installed_non_ea_prefix_supported_packages;
    is(
        \@pkgs,
        ['alt-php42'],
        '_get_installed_non_ea_prefix_supported_packages results are cached',
    );

    return;
}

sub test__has_non_ea_prefix_packages : Test(2) ($self) {

    my $cpev = cpev->new();
    my $ea4  = $cpev->get_component('EA4');

    my $mock_ea4 = Test::MockModule->new('Elevate::Components::EA4');
    $mock_ea4->redefine(
        _get_installed_non_ea_prefix_supported_packages => sub { return; },
    );

    is( $ea4->_has_non_ea_prefix_packages, 0, 'Returns false when there are no additional prefix packages installed' );

    $mock_ea4->redefine(
        _get_installed_non_ea_prefix_supported_packages => sub { return ( 1, 2, 3 ); },
    );

    is( $ea4->_has_non_ea_prefix_packages, 1, 'Returns true when there are additional prefix packages installed' );

    return;
}

=pod

=cut

## helpers

sub _message_run_ea_current_to_profile ( $success = 0 ) {

    my $target = Elevate::OS::ea_alias();

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

sub _get_os_hash ($self) {
    return (
        alma   => [8],
        cent   => [7],
        cloud  => [ 7, 8 ],
        ubuntu => [20],
    );
}

1;
